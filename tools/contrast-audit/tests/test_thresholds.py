import pytest

from contrast_audit.palette import hex_to_rgb, lightness_delta
from contrast_audit.report import (BODY_DELTA_L, GLANCE_DELTA_L, ROLE_BACKGROUND,
                                   ROLE_GUIDE, ROLE_TEXT, Finding, required_delta_l,
                                   summarise)

# Every pair below was judged by eye before the thresholds were fitted, so they
# are a check on the numbers rather than a restatement of them.
JUDGED = [
    ("latte body text",         "#4c4f69", "#eff1f5", "body"),
    ("frappe body text",        "#c6d0f5", "#303446", "body"),
    ("latte comments",          "#9ca0b0", "#eff1f5", "body"),
    ("frappe comments",         "#737994", "#303446", "body"),
    ("helix linenr latte",      "#bcc0cc", "#eff1f5", "glance"),
    ("helix linenr frappe",     "#51576d", "#303446", "glance"),
    ("fzf green on bar latte",  "#40a02b", "#6c6f85", "glance"),
    ("fzf green on bar frappe", "#a6d189", "#737994", "body"),
    ("eza pale end latte",      "#8eefff", "#eff1f5", "below"),
]


def tier(delta):
    if delta >= BODY_DELTA_L:
        return "body"
    return "glance" if delta >= GLANCE_DELTA_L else "below"


@pytest.mark.parametrize("name, fg, bg, expected", JUDGED)
def test_the_thresholds_agree_with_the_eye(name, fg, bg, expected):
    delta = lightness_delta(hex_to_rgb(fg), hex_to_rgb(bg))
    assert tier(delta) == expected, f"{name}: ΔL {delta:.3f}"


def test_a_guide_is_held_to_the_lower_bar():
    # Structure that reads as loudly as prose is structure competing with it.
    assert required_delta_l(ROLE_GUIDE) < required_delta_l(ROLE_TEXT)
    assert required_delta_l(ROLE_BACKGROUND) == 0.0


def _finding(delta, role=ROLE_TEXT):
    return Finding(fg=(0, 0, 0), bg=(255, 255, 255), ratio=21.0, delta_l=delta,
                   count=1, sample="x", tier="ansi", token=None, role=role)


def test_the_summary_counts_by_the_calibrated_measure():
    s = summarise([_finding(0.50), _finding(0.15), _finding(0.02)])
    assert s["below_body"] == 2
    assert s["below_glance"] == 1
    assert s["worst_delta"] == pytest.approx(0.02)


def test_a_guide_below_body_is_not_counted_short():
    # 0.15 is doing exactly what a separator should: legible, not shouting.
    assert summarise([_finding(0.15, ROLE_GUIDE)], strict=True)["short_for_role"] == 0
    assert summarise([_finding(0.15, ROLE_TEXT)], strict=True)["short_for_role"] == 1
