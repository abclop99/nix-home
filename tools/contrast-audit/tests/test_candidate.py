import pytest

from contrast_audit.candidate import (
    adjust_tokens,
    oklch_to_rgb,
    rgb_to_oklch,
    shift_to_ratio,
)
from contrast_audit.palette import contrast_ratio, hex_to_rgb, relative_luminance

BASE = hex_to_rgb("#eff1f5")     # Catppuccin Latte base
DARK_BASE = hex_to_rgb("#303446")  # Catppuccin Frappe base
LATTE_GREEN = hex_to_rgb("#40a02b")
LATTE_SKY = hex_to_rgb("#04a5e5")
FRAPPE_RED = hex_to_rgb("#e78284")


@pytest.mark.parametrize("hexval", [
    "#40a02b", "#04a5e5", "#fe640b", "#eff1f5", "#000000", "#ffffff",
    "#4c4f69", "#d20f39",
])
def test_oklch_round_trip_is_lossless_to_the_byte(hexval):
    rgb = hex_to_rgb(hexval)
    assert oklch_to_rgb(*rgb_to_oklch(rgb)) == rgb


def test_hue_survives_the_move():
    _, _, h_before = rgb_to_oklch(LATTE_GREEN)
    _, _, h_after = rgb_to_oklch(shift_to_ratio(LATTE_GREEN, BASE, 4.5))
    assert abs(h_after - h_before) < 0.02  # radians


def test_the_move_reaches_the_target():
    for colour in (LATTE_GREEN, LATTE_SKY, hex_to_rgb("#df8e1d")):
        out = shift_to_ratio(colour, BASE, 4.5)
        assert contrast_ratio(out, BASE) >= 4.5


def test_the_move_stops_at_the_nearest_version_that_works():
    # Not over-shot: it should land just above the target, not far past it.
    out = shift_to_ratio(LATTE_GREEN, BASE, 4.5)
    assert 4.5 <= contrast_ratio(out, BASE) < 4.7


def test_a_colour_already_clearing_the_target_is_untouched():
    text = hex_to_rgb("#4c4f69")            # 7.06:1 on base
    assert shift_to_ratio(text, BASE, 4.5) == text


def test_a_light_background_darkens():
    out = shift_to_ratio(LATTE_SKY, BASE, 4.5)
    assert relative_luminance(out) < relative_luminance(LATTE_SKY)


def test_a_dark_background_lightens_instead_of_darkening():
    # The regression this replaced: assuming "darker" here returned #000000 at
    # 1.71:1 and reported it as clearing 7:1.
    out = shift_to_ratio(FRAPPE_RED, DARK_BASE, 7.0)
    assert relative_luminance(out) > relative_luminance(FRAPPE_RED)
    assert contrast_ratio(out, DARK_BASE) >= 7.0


def test_an_unreachable_target_returns_the_closer_extreme_not_the_wrong_one():
    # 21:1 is unreachable against a mid-grey from either end. Whatever comes
    # back must at least beat the colour it replaces, never undercut it.
    grey = hex_to_rgb("#808080")
    out = shift_to_ratio(LATTE_SKY, grey, 21.0)
    assert contrast_ratio(out, grey) > contrast_ratio(LATTE_SKY, grey)


def test_adjust_tokens_on_a_dark_background_improves_every_token_it_moves():
    tokens = {"red": FRAPPE_RED, "blue": hex_to_rgb("#8caaee"),
              "mauve": hex_to_rgb("#ca9ee6")}
    for name, new in adjust_tokens(tokens, DARK_BASE, 7.0).items():
        assert contrast_ratio(new, DARK_BASE) > contrast_ratio(tokens[name], DARK_BASE)


def test_adjust_tokens_reports_only_what_changed():
    tokens = {"green": LATTE_GREEN, "text": hex_to_rgb("#4c4f69")}
    out = adjust_tokens(tokens, BASE, 4.5)
    assert set(out) == {"green"}


def test_adjust_tokens_honours_the_only_filter():
    tokens = {"green": LATTE_GREEN, "sky": LATTE_SKY}
    out = adjust_tokens(tokens, BASE, 4.5, only=("green",))
    assert set(out) == {"green"}
