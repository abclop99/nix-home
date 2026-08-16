import pytest

from contrast_audit.calibrate import (HUES, MAX_CHROMA, STEPS, at_delta, grid,
                                      key, live_flavor, main, render, rows)
from contrast_audit.candidate import rgb_to_oklch
from contrast_audit.palette import hex_to_rgb, lightness_delta, oklab_lightness

LIGHT = hex_to_rgb("#eff1f5")   # Latte base
DARK = hex_to_rgb("#303446")    # Frappe base
MID = hex_to_rgb("#6c6f85")     # fzf's selected row on Latte


@pytest.mark.parametrize("bg", [LIGHT, DARK, MID])
@pytest.mark.parametrize("target", STEPS)
def test_the_ramp_hits_the_requested_delta(bg, target):
    for _, hue, chroma in HUES:
        got = lightness_delta(at_delta(bg, target, chroma, hue), bg)
        assert got == pytest.approx(target, abs=0.005)


@pytest.mark.parametrize("bg", [LIGHT, MID])
def test_a_light_background_ramps_darker(bg):
    # Away from the background is the readable direction, not simply "down".
    out = at_delta(bg, 0.2, 0.0, 0.0)
    assert oklab_lightness(out) < oklab_lightness(bg)


def test_a_dark_background_ramps_lighter():
    out = at_delta(DARK, 0.2, 0.0, 0.0)
    assert oklab_lightness(out) > oklab_lightness(DARK)


def test_the_grey_column_is_actually_neutral():
    # It is the baseline the chroma penalty is measured against, so any
    # colour in it would corrupt the comparison.
    for target in STEPS:
        assert rgb_to_oklch(at_delta(LIGHT, target, 0.0, 0.0))[1] < 0.001


def test_the_coloured_columns_carry_chroma_where_the_gamut_allows():
    # Not asserted at the pale end: close to a light background every colour is
    # close to white, and white has no chroma. That limit is real and the
    # --chroma-table flag reports it rather than hiding it.
    for _, hue, chroma in HUES[1:]:
        assert rgb_to_oklch(at_delta(LIGHT, 0.30, chroma, hue))[1] > 0.10


def test_direction_can_be_forced_against_a_mid_background():
    # fzf's selected row carries text on both sides of it, and the two sides
    # need not share a threshold -- that is the polarity question.
    up = at_delta(MID, 0.2, 0.0, 0.0, lighter=True)
    down = at_delta(MID, 0.2, 0.0, 0.0, lighter=False)
    assert oklab_lightness(up) > oklab_lightness(MID) > oklab_lightness(down)
    assert lightness_delta(up, MID) == pytest.approx(0.2, abs=0.005)
    assert lightness_delta(down, MID) == pytest.approx(0.2, abs=0.005)


def test_the_request_is_clamped_to_the_gamut_not_left_out_of_range():
    # MAX_CHROMA is deliberately unreachable; oklch_to_rgb must bisect it down
    # to something sRGB can display rather than clipping to a wrong hue.
    out = at_delta(LIGHT, 0.30, MAX_CHROMA, 2.55)
    assert rgb_to_oklch(out)[1] < MAX_CHROMA
    assert all(0 <= c <= 255 for c in out)


@pytest.mark.parametrize("background, expected", [
    ("#eff1f5", "latte"),
    ("#303446", "frappe"),
])
def test_live_flavor_reads_the_terminal_not_an_assumption(tmp_path, background,
                                                          expected):
    # Building one flavour's ramp over the other's background measures nothing,
    # and does it silently, so the flavour is detected rather than assumed.
    conf = tmp_path / "kitty.conf"
    conf.write_text(f"background {background}\nforeground #4c4f69\n")
    assert live_flavor(conf) == expected


def test_live_flavor_falls_back_when_there_is_no_config(tmp_path):
    assert live_flavor(tmp_path / "absent.conf") == "latte"


def test_every_cell_gets_its_own_sample():
    # A repeated sample measures recognition, not reading: by the third row you
    # know what it says and can "read" it well below the contrast where you
    # could actually resolve it. That reports a detection threshold under the
    # name of a reading one, and detection leans on chroma much harder, so it
    # flatters the saturated columns specifically.
    flat = [text for row in grid(1234) for text in row]
    assert len(set(flat)) == len(flat)


def test_the_key_is_the_same_draw_as_the_grid():
    # Not merely equal today: a key generated from its own draw could drift
    # from the grid it checks, and a correct reading would then look wrong.
    text = key(4242)
    for row in grid(4242):
        for cell in row:
            assert cell in text


def test_the_seed_reproduces_the_grid_and_nothing_else_does():
    assert grid(7) == grid(7)
    assert grid(7) != grid(8)


def test_the_grid_is_not_in_the_key_of_another_seed():
    assert key(11) != key(12)


def test_key_without_a_seed_refuses_rather_than_inventing_one():
    # A key drawn from a fresh seed matches no grid, so every row would read as
    # a failed reading -- silently, and in the direction of raising the floor.
    with pytest.raises(SystemExit):
        main(["--key"])


def test_render_puts_the_drawn_samples_on_screen():
    out = render(LIGHT, "latte", [], seed=99)
    for row in grid(99):
        for cell in row:
            assert cell in out


def test_the_default_order_puts_the_lowest_contrast_first():
    # Which end you start from is the whole instruction, so it has to be a
    # fact about the output rather than a claim in the prompt text.
    assert [t for t, _ in rows(5)] == list(STEPS)
    assert rows(5)[0][0] < rows(5)[-1][0]


def test_descend_reverses_the_rows_without_redrawing_them():
    # A seed has to name the same grid whichever way it is read, or the key
    # from one direction would fail against the other.
    assert [t for t, _ in rows(5, descend=True)] == list(STEPS)[::-1]
    assert dict(rows(5, descend=True)) == dict(rows(5))


def test_the_key_follows_the_direction_it_was_asked_for():
    lines = [ln for ln in key(5, descend=True).splitlines() if ln.startswith("  0.")]
    assert lines[0].startswith(f"  {STEPS[-1]:.2f}")
