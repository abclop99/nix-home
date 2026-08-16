"""Resolve symbolic cell colours to RGB, recording where each came from.

Provenance is the point.  A colour that came from an ANSI slot is correctable
once in programs.kitty.settings and reaches every ANSI-emitting programme at
the same time; a truecolour value matching a Catppuccin token moves when
catppuccin.flavor changes; a truecolour value matching nothing is themed
outside Catppuccin entirely and no palette change will ever reach it.

Two optional lenses model what is actually on screen rather than what the
theme specifies -- see the module docstring of palette.composite.
"""
from dataclasses import dataclass
from enum import Enum

from contrast_audit.emulate import Cell
from contrast_audit.palette import RGB, Palette, composite, hex_to_rgb

_HEX_DIGITS = set("0123456789abcdefABCDEF")


class ColorKind(Enum):
    DEFAULT = "default"
    ANSI = "ansi"
    CUBE = "cube"
    TRUECOLOR = "truecolor"


# pyte's own ANSI names.  Index 3 is "brown", not "yellow"; bright variants are
# "bright" + the same name, giving "brightbrown" for 11.  Verified against
# pyte 0.8.2's graphics.FG_ANSI / FG_AIXTERM.
_ANSI_NAMES = ("black", "red", "green", "brown",
               "blue", "magenta", "cyan", "white")
_NAME_TO_INDEX = {n: i for i, n in enumerate(_ANSI_NAMES)}
_NAME_TO_INDEX.update({f"bright{n}": i + 8 for i, n in enumerate(_ANSI_NAMES)})
# pyte 0.8.2 typo: BG_AIXTERM[105] is "bfightmagenta", fixed only on upstream
# master.  It reaches us only as a background.  Unhandled it falls through to
# the hex parser and aborts the sweep mid-run.
_NAME_TO_INDEX["bfightmagenta"] = 13

_CUBE_STEPS = (0, 95, 135, 175, 215, 255)


def _cube_rgb(index: int) -> RGB:
    """The xterm 256 colour cube and grey ramp."""
    if index < 232:
        n = index - 16
        return (_CUBE_STEPS[n // 36], _CUBE_STEPS[(n // 6) % 6], _CUBE_STEPS[n % 6])
    level = 8 + (index - 232) * 10
    return (level, level, level)


@dataclass(frozen=True)
class RGBCell:
    char: str
    fg: RGB
    bg: RGB
    fg_kind: ColorKind
    bg_kind: ColorKind
    bold: bool = False
    dim: bool = False


def resolve_color(token: str, palette: Palette, is_background: bool) -> tuple[RGB, ColorKind]:
    if token == "default":
        base = palette.background if is_background else palette.foreground
        return base, ColorKind.DEFAULT
    if token in _NAME_TO_INDEX:
        return palette.ansi[_NAME_TO_INDEX[token]], ColorKind.ANSI
    if len(token) == 5 and token.startswith("idx") and token[3:].isdigit():
        return palette.ansi[int(token[3:])], ColorKind.ANSI
    if len(token) == 4 and token.startswith("c") and token[1:].isdigit():
        return _cube_rgb(int(token[1:])), ColorKind.CUBE
    if len(token) == 6 and all(c in _HEX_DIGITS for c in token):
        return hex_to_rgb(token), ColorKind.TRUECOLOR
    # Never guess: an unknown token means pyte changed or a case was missed,
    # and silently reading it as a colour would corrupt the measurement.
    raise ValueError(f"unrecognised pyte colour token: {token!r}")


def resolve_grid(
    grid: list[list[Cell]],
    palette: Palette,
    *,
    model_dim: bool = True,
    backdrop: RGB | None = None,
) -> list[list[RGBCell]]:
    """Turn a Cell grid into RGB with provenance.

    model_dim applies kitty's dim_opacity to cells carrying SGR 2, blending
    the foreground toward its own background -- otherwise dim text is measured
    at full colour and its contrast overstated.

    backdrop, when given, models kitty's background_opacity by compositing
    against what shows through the window.  Foregrounds are left alone: kitty
    renders glyphs opaque.  Only cells whose *final* background equals the
    default background are translucent -- see the gate below.
    """
    out = []
    for row in grid:
        resolved = []
        for cell in row:
            fg, fg_kind = resolve_color(cell.fg, palette, False)
            bg, bg_kind = resolve_color(cell.bg, palette, True)
            if cell.reverse:
                fg, bg = bg, fg
                fg_kind, bg_kind = bg_kind, fg_kind
            # kitty reduces a cell's alpha only when its final background
            # equals the default background: calc_background_opacity compares
            # bg_as_uint against bg_colors0, and bg_as_uint is resolved *after*
            # reverse (cell_vertex.glsl:314-316, 244-258).  Cells carrying an
            # explicit background render fully opaque.  Slots 1-7 come from
            # transparent_background_colors, which this config never sets.
            if (backdrop is not None and palette.background_opacity < 1.0
                    and bg == palette.background):
                bg = composite(bg, backdrop, palette.background_opacity)
            # dim is an alpha on the glyph (effective_text_alpha *= dim_opacity,
            # cell_vertex.glsl:327), so it blends over whatever the background
            # has already become -- it must follow the backdrop composite.
            if model_dim and cell.dim and palette.dim_opacity < 1.0:
                fg = composite(fg, bg, palette.dim_opacity)
            resolved.append(
                RGBCell(cell.char, fg, bg, fg_kind, bg_kind, cell.bold, cell.dim)
            )
        out.append(resolved)
    return out
