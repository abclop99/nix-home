import pytest

from contrast_audit.shader import (NEUTRAL, apply, multipliers, parse,
                                   temperature_to_rgb)

BLUE_LIGHT_FILTER = """
const float temperature = 2600.0;
const float temperatureStrength = 1.0;
"""


def test_the_2600k_white_point_matches_the_shader():
    # Computed by hand from blue-light-filter.glsl's own constants, so a
    # refactor of the port cannot quietly change what is being modelled.
    r, g, b = temperature_to_rgb(2600.0)
    assert r == pytest.approx(1.0, abs=1e-6)
    assert g == pytest.approx(0.650531, abs=1e-5)
    assert b == pytest.approx(0.303754, abs=1e-5)


def test_blue_is_the_channel_that_moves():
    r, g, b = temperature_to_rgb(2600.0)
    assert b < g < r


def test_zero_strength_is_a_no_op():
    # mix(color, color * white, 0) is color, so a disabled shader must model as
    # exactly neutral rather than as nearly neutral.
    assert multipliers(2600.0, 0.0) == NEUTRAL


def test_strength_interpolates_toward_the_white_point():
    full = multipliers(2600.0, 1.0)
    half = multipliers(2600.0, 0.5)
    assert half[2] == pytest.approx((1.0 + full[2]) / 2)


def test_a_daylight_temperature_barely_moves_anything():
    assert temperature_to_rgb(6500.0) == pytest.approx((1.0, 1.0, 1.0), abs=0.05)


def test_the_high_branch_is_taken_above_6500k():
    # Two different curve fits meet there; the cool side must not reuse the
    # warm matrix, which would send blue past 1.0 and clamp.
    r, _, b = temperature_to_rgb(20000.0)
    assert b >= r


def test_a_white_background_goes_orange():
    # The headline consequence: Latte's base is not a light neutral at night.
    assert apply((239, 241, 245), multipliers(2600.0)) == (239, 157, 74)


def test_filtering_is_clamped_to_the_byte_range():
    # At 1000K the blue coefficient comes out negative before the shader's own
    # clamp, so this checks the clamp is inside temperature_to_rgb rather than
    # left to produce a negative channel here.
    assert apply((255, 255, 255), multipliers(1000.0)) == (255, 62, 0)


def test_parse_reads_the_temperature_out_of_the_shader():
    assert parse(BLUE_LIGHT_FILTER) == pytest.approx(multipliers(2600.0, 1.0))


def test_parse_honours_a_retuned_strength():
    source = BLUE_LIGHT_FILTER.replace("Strength = 1.0", "Strength = 0.5")
    assert parse(source) == pytest.approx(multipliers(2600.0, 0.5))


def test_parse_declines_a_shader_it_does_not_understand():
    # vibrance.glsl ships alongside and has no temperature; guessing a white
    # point for it would corrupt every reading taken under it.
    assert parse("void main() { fragColor = texture(tex, v_texcoord); }") is None
