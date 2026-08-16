"""Kitty palette loading, and the two contrast measures the audit reports.

WCAG 2.1 contrast ratio is the primary number, because it is what accessibility
targets are written against.  It is also luminance-only, and that is a real
limitation rather than a footnote: it ignores chroma entirely, so it overstates
saturated colours (the Helmholtz-Kohlrausch effect makes them appear lighter
than their luminance, hence closer to a light background than the ratio claims),
it is blind to polarity, and its `+0.05` floor compresses the dark end so a dark
theme scores well for free -- Frappe here has *smaller* luminance gaps than Latte
and far better ratios.

So OKLCH lightness difference is reported alongside it.  OKLCH's L is
perceptually uniform, so a delta is comparable across hues in a way the ratio is
not.  Calibration points from Catppuccin Latte against its own base:

    body text (text)          dL 0.52   comfortable to read
    quiet structure (overlay0) dL 0.25   subordinate but legible
    surface2                   dL 0.20   very faint
    surface1                   dL 0.15   effectively invisible

No pass/fail threshold is attached to dL deliberately: inventing one would just
be a second arbitrary bar. It is there so a ratio can be sanity-checked against a
measure that accounts for hue, which matters most for the saturated accents where
the ratio is least trustworthy.


The palette is loaded from the *rendered* kitty.conf rather than the upstream
Catppuccin flavour file, following its `include` and then applying any later
colour directives.  That matters: kitty's precedence is later-wins, and
home-manager emits the Catppuccin include above its own `settings`, so an
override in programs.kitty.settings beats the theme.  Reading the rendered file
is what makes a candidate palette fix measurable by this same harness.
"""
from dataclasses import dataclass, field
from math import cbrt
from pathlib import Path

RGB = tuple[int, int, int]

# Catppuccin flavour tokens.  Used to tell "this truecolour came from the
# Catppuccin palette" (so it moves when catppuccin.flavor changes) from "this
# programme is themed by something else entirely".
_LATTE = {
    "base": "#eff1f5", "mantle": "#e6e9ef", "crust": "#dce0e8",
    "surface0": "#ccd0da", "surface1": "#bcc0cc", "surface2": "#acb0be",
    "overlay0": "#9ca0b0", "overlay1": "#8c8fa1", "overlay2": "#7c7f93",
    "subtext0": "#6c6f85", "subtext1": "#5c5f77", "text": "#4c4f69",
    "rosewater": "#dc8a78", "flamingo": "#dd7878", "pink": "#ea76cb",
    "mauve": "#8839ef", "red": "#d20f39", "maroon": "#e64553",
    "peach": "#fe640b", "yellow": "#df8e1d", "green": "#40a02b",
    "teal": "#179299", "sky": "#04a5e5", "sapphire": "#209fb5",
    "blue": "#1e66f5", "lavender": "#7287fd",
}
_FRAPPE = {
    "base": "#303446", "mantle": "#292c3c", "crust": "#232634",
    "surface0": "#414559", "surface1": "#51576d", "surface2": "#626880",
    "overlay0": "#737994", "overlay1": "#838ba7", "overlay2": "#949cbb",
    "subtext0": "#a5adce", "subtext1": "#b5bfe2", "text": "#c6d0f5",
    "rosewater": "#f2d5cf", "flamingo": "#eebebe", "pink": "#f4b8e4",
    "mauve": "#ca9ee6", "red": "#e78284", "maroon": "#ea999c",
    "peach": "#ef9f76", "yellow": "#e5c890", "green": "#a6d189",
    "teal": "#81c8be", "sky": "#99d1db", "sapphire": "#85c1dc",
    "blue": "#8caaee", "lavender": "#babbf1",
}


def hex_to_rgb(value: str) -> RGB:
    h = value.lstrip("#")
    if len(h) != 6:
        raise ValueError(f"not a 6-digit hex colour: {value!r}")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def rgb_to_hex(rgb: RGB) -> str:
    return "#{:02x}{:02x}{:02x}".format(*rgb)


TOKENS = {
    "latte": {k: hex_to_rgb(v) for k, v in _LATTE.items()},
    "frappe": {k: hex_to_rgb(v) for k, v in _FRAPPE.items()},
}


def srgb_to_linear(c: float) -> float:
    """Undo the sRGB transfer function. c and the result are 0..1."""
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def linear_to_srgb(c: float) -> float:
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def _linearize(channel: int) -> float:
    return srgb_to_linear(channel / 255.0)


def relative_luminance(rgb: RGB) -> float:
    r, g, b = (_linearize(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_ratio(a: RGB, b: RGB) -> float:
    la, lb = relative_luminance(a), relative_luminance(b)
    lo, hi = min(la, lb), max(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def rgb_to_oklab(rgb: RGB) -> tuple[float, float, float]:
    """sRGB -> OKLab. Bjorn Ottosson's matrices; the single copy in this tool."""
    r, g, b = (_linearize(c) for c in rgb)
    l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    return (
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    )


def oklab_lightness(rgb: RGB) -> float:
    """Perceptually uniform lightness: 0 is black, ~1 is white."""
    return rgb_to_oklab(rgb)[0]


def lightness_delta(a: RGB, b: RGB) -> float:
    """Perceptual lightness difference, 0..1.

    Reported next to contrast_ratio because it is comparable across hues: the
    ratio is luminance-only and overstates saturated colours, so two pairs with
    the same ratio can read very differently.  See the module docstring for
    calibration points.
    """
    return abs(oklab_lightness(a) - oklab_lightness(b))


def composite(bg: RGB, behind: RGB, opacity: float) -> RGB:
    """Blend a background against what shows through it.

    kitty's background_opacity makes only the BACKGROUND translucent; glyphs
    render opaque.  So the contrast actually experienced is the foreground
    against this blend.  Compositors blend in sRGB space, so that is what is
    modelled here rather than a linear-light mix.
    """
    if not 0.0 <= opacity <= 1.0:
        raise ValueError(f"opacity must be in [0, 1], got {opacity}")
    return tuple(  # type: ignore[return-value]
        round(opacity * b + (1 - opacity) * w) for b, w in zip(bg, behind)
    )


@dataclass(frozen=True)
class Palette:
    name: str
    foreground: RGB
    background: RGB
    ansi: tuple[RGB, ...]  # exactly 16 entries, indices 0-15
    tokens: dict[str, RGB] = field(default_factory=dict)
    # Read from the same kitty.conf rather than hardcoded, so the harness
    # measures this terminal's actual settings.
    dim_opacity: float = 1.0
    background_opacity: float = 1.0

    def token_for(self, rgb: RGB) -> str | None:
        """Name of the Catppuccin token with this exact value, if any."""
        for name, value in self.tokens.items():
            if value == rgb:
                return name
        return None


def _scan(path: Path, into: dict[str, str], names: list[str]) -> None:
    """Apply one conf file's directives, following includes in order.

    Keys off the first whitespace token, never "line starts with #" -- comment
    lines and colour values both begin with a hash.
    """
    path = Path(path)
    for line in path.read_text().splitlines():
        if line.startswith("## name:"):
            names.append(line.split(":", 1)[1].strip())
            continue
        parts = line.split()
        if not parts:
            continue
        if parts[0] == "include" and len(parts) >= 2:
            included = Path(parts[1])
            if not included.is_absolute():
                included = path.parent / included
            if included.exists():
                _scan(included, into, names)
            continue
        if len(parts) >= 2 and parts[1].startswith("#") and len(parts[1]) == 7:
            into[parts[0]] = parts[1]
        elif parts[0] in ("dim_opacity", "background_opacity") and len(parts) >= 2:
            into[parts[0]] = parts[1]


def load_palette(kitty_conf: Path, flavor: str | None = None) -> Palette:
    """Load the effective palette from a rendered kitty.conf."""
    kitty_conf = Path(kitty_conf)
    values: dict[str, str] = {}
    names: list[str] = []
    _scan(kitty_conf, values, names)

    missing = [f"color{i}" for i in range(16) if f"color{i}" not in values]
    if missing:
        raise ValueError(f"{kitty_conf}: missing colour keys: {', '.join(missing)}")
    for key in ("foreground", "background"):
        if key not in values:
            raise ValueError(f"{kitty_conf}: missing {key}")

    name = names[-1] if names else kitty_conf.stem
    if flavor is None:
        flavor = "latte" if "latte" in name.lower() else "frappe"

    def _opacity(key: str) -> float:
        try:
            return float(values.get(key, 1.0))
        except ValueError:
            return 1.0

    return Palette(
        name=name,
        foreground=hex_to_rgb(values["foreground"]),
        background=hex_to_rgb(values["background"]),
        ansi=tuple(hex_to_rgb(values[f"color{i}"]) for i in range(16)),
        tokens=TOKENS.get(flavor, {}),
        dim_opacity=_opacity("dim_opacity"),
        background_opacity=_opacity("background_opacity"),
    )
