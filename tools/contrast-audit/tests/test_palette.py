import pytest

from contrast_audit.palette import (
    hex_to_rgb as _hex,
    lightness_delta,
    oklab_lightness,
)

WHITE, BLACK = (255, 255, 255), (0, 0, 0)


def test_oklab_lightness_spans_zero_to_one():
    assert oklab_lightness(BLACK) == pytest.approx(0.0, abs=1e-6)
    assert oklab_lightness(WHITE) == pytest.approx(1.0, abs=1e-3)


def test_lightness_delta_is_symmetric_and_zero_for_equal_colours():
    a, b = _hex("#40a02b"), _hex("#1e66f5")
    assert lightness_delta(a, b) == pytest.approx(lightness_delta(b, a))
    assert lightness_delta(a, a) == 0.0


def test_lightness_delta_matches_the_documented_calibration_points():
    # The docstring quotes these against Latte's base; if they drift the
    # calibration advice in the report legend becomes wrong.
    base = _hex("#eff1f5")
    assert lightness_delta(_hex("#4c4f69"), base) == pytest.approx(0.52, abs=0.01)
    assert lightness_delta(_hex("#9ca0b0"), base) == pytest.approx(0.25, abs=0.01)
    assert lightness_delta(_hex("#bcc0cc"), base) == pytest.approx(0.15, abs=0.01)


def test_delta_l_separates_pairs_the_ratio_conflates():
    # Two pairs with near-identical WCAG ratios but different perceived
    # lightness gaps -- the reason dL is reported at all.
    from contrast_audit.palette import contrast_ratio
    base = _hex("#eff1f5")
    yellow, pink = _hex("#df8e1d"), _hex("#ea76cb")
    assert contrast_ratio(yellow, base) == pytest.approx(
        contrast_ratio(pink, base), abs=0.05)
    assert lightness_delta(yellow, base) != pytest.approx(
        lightness_delta(pink, base), abs=0.005)

from contrast_audit.palette import (
    TOKENS,
    Palette,
    composite,
    contrast_ratio,
    hex_to_rgb,
    load_palette,
)


def test_hex_to_rgb_uppercase():
    # kitty theme confs use uppercase hex
    assert hex_to_rgb("#EFF1F5") == (239, 241, 245)


def test_hex_to_rgb_lowercase():
    assert hex_to_rgb("#4c4f69") == (76, 79, 105)


def test_hex_to_rgb_rejects_short():
    with pytest.raises(ValueError, match="6-digit"):
        hex_to_rgb("#fff")


def test_contrast_ratio_black_on_white_is_maximal():
    assert contrast_ratio((0, 0, 0), (255, 255, 255)) == pytest.approx(21.0, abs=0.01)


def test_contrast_ratio_identical_colours_is_one():
    assert contrast_ratio((17, 34, 51), (17, 34, 51)) == pytest.approx(1.0, abs=1e-9)


def test_contrast_ratio_is_symmetric():
    a, b = (76, 79, 105), (239, 241, 245)
    assert contrast_ratio(a, b) == pytest.approx(contrast_ratio(b, a))


def test_contrast_ratio_latte_text_on_base():
    # Latte text #4c4f69 on base #eff1f5, computed independently as 7.06
    assert contrast_ratio((76, 79, 105), (239, 241, 245)) == pytest.approx(7.06, abs=0.01)


def test_composite_at_full_opacity_is_identity():
    assert composite((48, 52, 70), (0, 0, 0), 1.0) == (48, 52, 70)


def test_composite_at_zero_opacity_is_the_backdrop():
    assert composite((48, 52, 70), (10, 20, 30), 0.0) == (10, 20, 30)


def test_composite_blends_toward_the_backdrop():
    # Latte base over black at kitty's configured 0.9.
    # 0.9*245 is exactly 220.5, and Python's round() is half-to-even, so the
    # blue channel lands on 220 rather than 221. A 1/255 quantisation choice
    # with no effect on any contrast ratio.
    assert composite((239, 241, 245), (0, 0, 0), 0.9) == (215, 217, 220)


def test_composite_rejects_out_of_range_opacity():
    with pytest.raises(ValueError, match="opacity"):
        composite((0, 0, 0), (0, 0, 0), 1.5)


def _write_theme(tmp_path):
    theme = tmp_path / "Catppuccin-Latte.conf"
    theme.write_text(
        "# vim:ft=kitty\n"
        "## name:     Catppuccin-Latte\n"
        "\n"
        "foreground              #4C4F69\n"
        "background              #EFF1F5\n"
        + "".join(f"color{i} #00000{i % 10}\n" for i in range(16))
    )
    return theme


def test_load_follows_include(tmp_path):
    theme = _write_theme(tmp_path)
    conf = tmp_path / "kitty.conf"
    conf.write_text(f"font_family Fira Code\ninclude {theme}\n")
    pal = load_palette(conf)
    assert isinstance(pal, Palette)
    assert pal.name == "Catppuccin-Latte"
    assert pal.foreground == (76, 79, 105)
    assert pal.background == (239, 241, 245)
    assert len(pal.ansi) == 16
    assert pal.ansi[3] == (0, 0, 3)


def test_later_settings_override_the_include(tmp_path):
    """The whole point: a fix in programs.kitty.settings must be measurable."""
    theme = _write_theme(tmp_path)
    conf = tmp_path / "kitty.conf"
    conf.write_text(f"include {theme}\ncolor3 #8A5E00\nforeground #111111\n")
    pal = load_palette(conf)
    assert pal.ansi[3] == (138, 94, 0)
    assert pal.foreground == (17, 17, 17)


def test_include_before_override_order_matters(tmp_path):
    """An override placed BEFORE the include must lose, as kitty does it."""
    theme = _write_theme(tmp_path)
    conf = tmp_path / "kitty.conf"
    conf.write_text(f"color3 #8A5E00\ninclude {theme}\n")
    pal = load_palette(conf)
    assert pal.ansi[3] == (0, 0, 3)  # the theme wins


def test_relative_include_resolves_against_the_conf(tmp_path):
    _write_theme(tmp_path)
    conf = tmp_path / "kitty.conf"
    conf.write_text("include Catppuccin-Latte.conf\n")
    assert load_palette(conf).background == (239, 241, 245)


def test_comment_lines_are_not_parsed_as_colours(tmp_path):
    theme = _write_theme(tmp_path)
    conf = tmp_path / "kitty.conf"
    conf.write_text(f"include {theme}\n# color3 #FFFFFF\n")
    assert load_palette(conf).ansi[3] == (0, 0, 3)


def test_load_rejects_incomplete(tmp_path):
    conf = tmp_path / "kitty.conf"
    conf.write_text("foreground #4C4F69\n")
    with pytest.raises(ValueError, match="colour keys"):
        load_palette(conf)


def test_flavor_inferred_from_theme_name(tmp_path):
    theme = _write_theme(tmp_path)
    conf = tmp_path / "kitty.conf"
    conf.write_text(f"include {theme}\n")
    assert load_palette(conf).tokens == TOKENS["latte"]


def test_token_lookup():
    theme_tokens = TOKENS["latte"]
    pal = Palette("t", (0, 0, 0), (255, 255, 255), tuple([(0, 0, 0)] * 16),
                  theme_tokens)
    assert pal.token_for((136, 57, 239)) == "mauve"
    assert pal.token_for((1, 2, 3)) is None


def test_flavor_tokens_present():
    assert TOKENS["latte"]["mauve"] == (136, 57, 239)
    assert TOKENS["frappe"]["base"] == (48, 52, 70)
    assert len(TOKENS["latte"]) == len(TOKENS["frappe"]) == 26
