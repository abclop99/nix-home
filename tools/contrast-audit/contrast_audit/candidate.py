"""Generate a variant of a palette that clears a contrast target.

Moving lightness in sRGB washes hues out and shifts them; OKLCH keeps the hue
angle fixed and lets lightness move independently, which is the difference
between "Catppuccin, darker" and "some other green".  Chroma is preserved where
sRGB can represent it and reduced only as far as the gamut forces, so each
colour stays as saturated as it can at its new lightness.

Matrices are Bjorn Ottosson's sRGB<->OKLab pair.
"""
from __future__ import annotations

from dataclasses import replace
from math import atan2, cos, hypot, sin

from contrast_audit.palette import (
    RGB,
    contrast_ratio,
    linear_to_srgb,
    rgb_to_oklab,
)

# The fourteen tokens Catppuccin marks as accents -- what syntax highlighting
# draws strings, numbers, keywords, functions and operators with.  The greys
# (base, surface*, overlay*, subtext*) are deliberately excluded: they exist as
# a graded ramp near the background, and moving them all to clear a contrast
# target collapses that ramp into one colour.  Where a grey carries text -- eg
# helix using overlay2 for comments -- the fix is to reassign the role to
# subtext0/1, not to move the token.
ACCENTS = ("rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach",
           "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender")


def rgb_to_oklch(rgb: RGB) -> tuple[float, float, float]:
    """OKLab in polar form: lightness, chroma, hue angle in radians."""
    L, a, b = rgb_to_oklab(rgb)
    return L, hypot(a, b), atan2(b, a)


def _oklch_to_linear(L: float, C: float, h: float) -> tuple[float, float, float]:
    a, b = C * cos(h), C * sin(h)
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    return (
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    )


def _in_gamut(channels: tuple[float, float, float], eps: float = 1e-4) -> bool:
    return all(-eps <= c <= 1 + eps for c in channels)


def oklch_to_rgb(L: float, C: float, h: float) -> RGB:
    """Convert to sRGB, reducing chroma only as far as the gamut requires."""
    lo, hi = 0.0, C
    if not _in_gamut(_oklch_to_linear(L, C, h)):
        for _ in range(24):                     # bisect on chroma
            mid = (lo + hi) / 2
            if _in_gamut(_oklch_to_linear(L, mid, h)):
                lo = mid
            else:
                hi = mid
        C = lo
    linear = _oklch_to_linear(L, C, h)
    return tuple(  # type: ignore[return-value]
        max(0, min(255, round(linear_to_srgb(min(max(c, 0.0), 1.0)) * 255)))
        for c in linear
    )


def shift_to_ratio(fg: RGB, bg: RGB, target: float) -> RGB:
    """The nearest version of fg, at its own hue, that clears target on bg.

    Which way to move is read off the background rather than assumed: darkening
    raises contrast against a light background and *lowers* it against a dark
    one.  Assuming "darker" drove every Frappe accent to black and reported it
    as an improvement -- red went 4.65:1 -> #000000 at 1.71:1.  So both ends of
    the lightness axis are measured and the further one is bisected toward.

    Nearest rather than any-that-works: over-shooting costs vibrancy for no
    readability gain, and the point is to move each colour the minimum distance
    that makes it legible.
    """
    if contrast_ratio(fg, bg) >= target:
        return fg
    L, C, h = rgb_to_oklch(fg)
    black, white = oklch_to_rgb(0.0, C, h), oklch_to_rgb(1.0, C, h)
    if contrast_ratio(black, bg) >= contrast_ratio(white, bg):
        end, limit = 0.0, black
    else:
        end, limit = 1.0, white
    if contrast_ratio(limit, bg) < target:
        return limit                            # unreachable even at the extreme
    lo, hi = end, L                             # lo clears the target, hi does not
    for _ in range(24):                         # bisect on lightness
        mid = (lo + hi) / 2
        if contrast_ratio(oklch_to_rgb(mid, C, h), bg) >= target:
            lo = mid
        else:
            hi = mid
    return oklch_to_rgb(lo, C, h)


def adjust_tokens(tokens: dict[str, RGB], background: RGB, target: float,
                  only: tuple[str, ...] | None = None) -> dict[str, RGB]:
    """Token -> moved token, for those that miss the target.

    `only` restricts the work to named tokens; passing the accents leaves the
    structural greys (base, surface*, overlay*) alone, which matters because
    those are chosen for their nearness to base and moving them would turn
    backgrounds into foregrounds.
    """
    out = {}
    for name, rgb in tokens.items():
        if only is not None and name not in only:
            continue
        fixed = shift_to_ratio(rgb, background, target)
        if fixed != rgb:
            out[name] = fixed
    return out


def remap_grid(grid, substitutions: dict[RGB, RGB]):
    """A copy of the grid with foregrounds substituted.

    Foregrounds only: the substitution models changing what a token *paints
    text with*, and rewriting backgrounds too would move the page's own base
    out from under the comparison.
    """
    return [
        [replace(c, fg=substitutions.get(c.fg, c.fg)) for c in row]
        for row in grid
    ]
