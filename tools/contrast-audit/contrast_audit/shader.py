"""Model hyprshade's screen shader, which sits between the palette and the eye.

The audit computes colours the terminal is told to draw.  For ten hours a night
that is not what reaches the eye: hyprshade's blue-light-filter multiplies every
pixel by a 2600K white point, so the palette is judged through a transform the
harness knew nothing about.

It is not a small transform.  At 2600K blue keeps 30% of its value, which turns
Latte's #eff1f5 background orange and Frappe's #303446 brown, and it collapses
the blue accents specifically.  Measuring a calibration strip through it and
labelling the rows with unfiltered lightness deltas produced numbers that looked
like a large hue effect and were mostly the filter: correcting for it pulled a
7x spread across the hue columns down to 1.7x.

The shader's own luminance-preservation block does nothing, despite the #define
that claims otherwise -- `lum / max(lum, 1e-5)` is 1.0 for every pixel that is
not almost exactly black, so the multiply is unopposed and the whole image
darkens.  That is upstream's bug, not one to work around here; it is modelled as
written because what matters is what is on the screen.
"""
from __future__ import annotations

import re
import subprocess
from pathlib import Path

from contrast_audit.palette import RGB

Multipliers = tuple[float, float, float]

NEUTRAL: Multipliers = (1.0, 1.0, 1.0)

_TEMPERATURE = re.compile(r"const\s+float\s+temperature\s*=\s*([0-9.]+)")
_STRENGTH = re.compile(r"const\s+float\s+temperatureStrength\s*=\s*([0-9.]+)")

# Straight port of colorTemperatureToRGB in blue-light-filter.glsl, which took
# it from shadertoy 4sc3D7.  Kept in the same shape as the original -- the
# constants are curve fits with no closed form to simplify to, and any tidying
# would only make the correspondence harder to check.
_BELOW = ((0.0, -2902.1955373783176, -8257.7997278925690),
          (0.0, 1669.5803561666639, 2575.2827530017594),
          (1.0, 1.3302673723350029, 1.8993753891711275))
_ABOVE = ((1745.0425298314172, 1216.6168361476490, -8257.7997278925690),
          (-2666.3474220535695, -2173.1012343082230, 2575.2827530017594),
          (0.55995389139931482, 0.70381203140554553, 1.8993753891711275))


def _smoothstep(edge0: float, edge1: float, x: float) -> float:
    t = (x - edge0) / (edge1 - edge0)
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def temperature_to_rgb(temperature: float) -> Multipliers:
    """The white point, as the shader computes it."""
    a, b, c = _BELOW if temperature <= 6500.0 else _ABOVE
    clamped = max(1000.0, min(40000.0, temperature))
    fade = _smoothstep(1000.0, 0.0, temperature)
    return tuple(  # type: ignore[return-value]
        (1.0 - fade) * max(0.0, min(1.0, a[i] / (clamped + b[i]) + c[i])) + fade
        for i in range(3)
    )


def multipliers(temperature: float, strength: float = 1.0) -> Multipliers:
    """What each encoded channel is scaled by.

    The shader's mix(color, color * white, strength) is per-channel linear in
    `white`, so the strength folds into the multiplier rather than needing a
    separate application step.
    """
    white = temperature_to_rgb(temperature)
    return tuple(1.0 + strength * (w - 1.0) for w in white)  # type: ignore[return-value]


def apply(rgb: RGB, mul: Multipliers) -> RGB:
    """Filter one colour.

    In encoded space, not linear: Hyprland's screen shader samples the
    composited framebuffer through a plain sampler2D, so the value the GLSL
    multiplies is the 8-bit sRGB-encoded one.
    """
    return tuple(  # type: ignore[return-value]
        max(0, min(255, round(c * m))) for c, m in zip(rgb, mul)
    )


def parse(source: str) -> Multipliers | None:
    """Read the white point out of a shader, or None if it is not one of these.

    Parsed rather than hardcoded so a retuned temperature in the shader is
    picked up instead of silently disagreeing with what is on screen -- the
    exact failure this module exists to stop.
    """
    temperature = _TEMPERATURE.search(source)
    if not temperature:
        return None
    strength = _STRENGTH.search(source)
    return multipliers(float(temperature.group(1)),
                       float(strength.group(1)) if strength else 1.0)


def active() -> tuple[Multipliers, str] | None:
    """The filter Hyprland is applying right now, with the shader's name.

    Detected rather than declared, for the same reason the flavour is: a
    measurement taken through an unnoticed transform does not announce itself,
    it just comes back wrong in a plausible-looking way.
    """
    try:
        out = subprocess.run(["hyprctl", "getoption", "decoration:screen_shader"],
                             capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    path = None
    for line in out.splitlines():
        if line.startswith("str:"):
            path = line[4:].strip()
    if not path or path == "[[EMPTY]]":
        return None
    try:
        mul = parse(Path(path).read_text())
    except OSError:
        return None
    return (mul, Path(path).stem) if mul else None
