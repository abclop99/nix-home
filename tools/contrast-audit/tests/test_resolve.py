import pytest

from contrast_audit.emulate import Cell
from contrast_audit.palette import Palette
from contrast_audit.resolve import ColorKind, RGBCell, resolve_color, resolve_grid

PAL = Palette(
    name="test",
    foreground=(10, 10, 10),
    background=(250, 250, 250),
    ansi=tuple((i, i, i) for i in range(16)),
    tokens={},
)


def cell(fg="default", bg="default", *, bold=False, dim=False, reverse=False):
    return Cell("X", fg, bg, bold, dim, reverse)


def test_default_foreground_and_background():
    assert resolve_color("default", PAL, False) == ((10, 10, 10), ColorKind.DEFAULT)
    assert resolve_color("default", PAL, True) == ((250, 250, 250), ColorKind.DEFAULT)


def test_ansi_names():
    assert resolve_color("red", PAL, False) == ((1, 1, 1), ColorKind.ANSI)
    assert resolve_color("brown", PAL, False) == ((3, 3, 3), ColorKind.ANSI)
    assert resolve_color("brightred", PAL, False) == ((9, 9, 9), ColorKind.ANSI)
    assert resolve_color("brightbrown", PAL, False) == ((11, 11, 11), ColorKind.ANSI)


def test_pyte_082_typo_is_absorbed():
    """pyte 0.8.2's BG_AIXTERM[105]; unhandled it aborts the sweep mid-run."""
    assert resolve_color("bfightmagenta", PAL, True) == ((13, 13, 13), ColorKind.ANSI)


def test_index_sentinel():
    assert resolve_color("idx07", PAL, False) == ((7, 7, 7), ColorKind.ANSI)
    assert resolve_color("idx15", PAL, False) == ((15, 15, 15), ColorKind.ANSI)


def test_cube_sentinel_matches_xterm():
    # 208-16 = 192 = 36*5 + 6*2 + 0 -> steps[5], steps[2], steps[0]
    assert resolve_color("c208", PAL, False) == ((255, 135, 0), ColorKind.CUBE)


def test_grey_ramp_sentinel():
    # 240 -> 8 + (240-232)*10 = 88
    assert resolve_color("c240", PAL, False) == ((88, 88, 88), ColorKind.CUBE)


def test_truecolor():
    assert resolve_color("123456", PAL, False) == ((18, 52, 86), ColorKind.TRUECOLOR)


def test_cube_and_truecolor_of_same_value_differ_in_kind():
    cube, cube_kind = resolve_color("c208", PAL, False)
    true, true_kind = resolve_color("ff8700", PAL, False)
    assert cube == true
    assert cube_kind is ColorKind.CUBE
    assert true_kind is ColorKind.TRUECOLOR


def test_unknown_token_raises_rather_than_guessing():
    with pytest.raises(ValueError, match="unrecognised"):
        resolve_color("chartreuse", PAL, False)


def test_grid_shape_preserved():
    out = resolve_grid([[cell()] * 3 for _ in range(2)], PAL)
    assert len(out) == 2 and len(out[0]) == 3
    assert all(isinstance(c, RGBCell) for row in out for c in row)


def test_reverse_swaps_colours_and_kinds():
    out = resolve_grid([[cell(fg="red", reverse=True)]], PAL)[0][0]
    assert out.fg == (250, 250, 250) and out.fg_kind is ColorKind.DEFAULT
    assert out.bg == (1, 1, 1) and out.bg_kind is ColorKind.ANSI


def test_bold_and_dim_carried_through():
    out = resolve_grid([[cell(bold=True, dim=True)]], PAL)[0][0]
    assert out.bold is True
    assert out.dim is True


# --- the two lenses -------------------------------------------------------

DIMPAL = Palette("d", (0, 0, 0), (200, 200, 200),
                 tuple((i, i, i) for i in range(16)), {},
                 dim_opacity=0.75, background_opacity=0.9)


def test_dim_blends_foreground_toward_its_background():
    plain = resolve_grid([[cell()]], DIMPAL)[0][0]
    dimmed = resolve_grid([[cell(dim=True)]], DIMPAL)[0][0]
    assert plain.fg == (0, 0, 0)
    # 0.75*0 + 0.25*200 = 50
    assert dimmed.fg == (50, 50, 50)
    assert dimmed.bg == plain.bg


def test_dim_can_be_switched_off():
    out = resolve_grid([[cell(dim=True)]], DIMPAL, model_dim=False)[0][0]
    assert out.fg == (0, 0, 0)


def test_dim_ignored_when_terminal_does_not_dim():
    out = resolve_grid([[cell(dim=True)]], PAL)[0][0]  # dim_opacity defaults to 1.0
    assert out.fg == (10, 10, 10)


def test_backdrop_composites_background_only():
    out = resolve_grid([[cell()]], DIMPAL, backdrop=(0, 0, 0))[0][0]
    # 0.9*200 + 0.1*0 = 180; foreground untouched because glyphs are opaque
    assert out.bg == (180, 180, 180)
    assert out.fg == (0, 0, 0)


def test_no_backdrop_leaves_background_alone():
    assert resolve_grid([[cell()]], DIMPAL)[0][0].bg == (200, 200, 200)


def test_backdrop_skips_cells_with_an_explicit_background():
    # kitty only reduces alpha where the background equals the default one;
    # an explicitly-coloured cell is opaque, so the wallpaper never shows
    # through a statusline, a diff highlight or a selection.
    out = resolve_grid([[cell(bg="red")]], DIMPAL, backdrop=(0, 0, 0))[0][0]
    assert out.bg == (1, 1, 1)


def test_backdrop_skips_reversed_cells():
    # reverse puts the foreground colour in the background slot, which no
    # longer matches the default background, so the cell renders opaque.
    out = resolve_grid([[cell(reverse=True)]], DIMPAL, backdrop=(0, 0, 0))[0][0]
    assert out.bg == (0, 0, 0)
    assert out.fg == (200, 200, 200)


def test_dim_blends_over_the_backdrop_composited_background():
    # kitty dims by lowering the glyph's alpha, so the glyph blends over the
    # already-composited background.  0.9*200 = 180, then 0.75*0 + 0.25*180.
    out = resolve_grid([[cell(dim=True)]], DIMPAL, backdrop=(0, 0, 0))[0][0]
    assert out.bg == (180, 180, 180)
    assert out.fg == (45, 45, 45)
