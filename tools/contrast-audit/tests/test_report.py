from contrast_audit.palette import Palette
from contrast_audit.report import (
    ROLE_BACKGROUND,
    ROLE_GUIDE,
    ROLE_TEXT,
    excerpt,
    findings,
    is_guide,
    summarise,
)
from contrast_audit.resolve import ColorKind, RGBCell

PAL = Palette(
    name="test",
    foreground=(0, 0, 0),
    background=(255, 255, 255),
    ansi=tuple((i, i, i) for i in range(16)),
    tokens={"faint": (200, 200, 200), "ink": (0, 0, 0)},
)

WHITE = (255, 255, 255)
FAINT = (200, 200, 200)
INK = (0, 0, 0)


def cells(text, fg=INK, bg=WHITE, kind=ColorKind.TRUECOLOR):
    return [RGBCell(ch, fg, bg, kind, ColorKind.DEFAULT, False, False)
            for ch in text]


def pad(row, width=20):
    return row + cells(" " * (width - len(row)))


def find(items, fg, bg):
    return next(f for f in items if f.fg == fg and f.bg == bg)


# -- role classification ----------------------------------------------------

def test_box_drawing_is_a_guide():
    assert is_guide("│")          # U+2502, helix's indent guide
    assert is_guide("─")
    assert is_guide("▏")          # block elements
    assert is_guide("·")          # rendered whitespace


def test_ascii_pipe_is_not_a_guide():
    # It is an operator in every language the fixtures display, so treating it
    # as decorative would hide real text.
    assert not is_guide("|")
    assert not is_guide("a")
    assert not is_guide("0")


def test_a_run_of_indent_guides_is_decorative():
    # The letter must carry a different colour: findings group by pair, so a
    # same-coloured glyph would join this group and make it text.
    grid = [pad(cells("│  │", fg=FAINT) + cells("x"))]
    guide = find(findings(grid, PAL), FAINT, WHITE)
    assert guide.role == ROLE_GUIDE


def test_a_run_containing_a_letter_is_text():
    grid = [pad(cells("│ a", fg=FAINT))]
    assert find(findings(grid, PAL), FAINT, WHITE).role == ROLE_TEXT


def test_blank_cells_off_the_page_background_are_background_role():
    # A statusline is mostly padding whose meaning lives in the background.
    grid = [pad(cells("x")), pad(cells("    ", bg=FAINT))]
    assert find(findings(grid, PAL), INK, FAINT).role == ROLE_BACKGROUND


# -- examples ---------------------------------------------------------------

def test_examples_mark_the_run_in_context():
    grid = [pad(cells("  ") + cells("│", fg=FAINT) + cells(" palette = {"))]
    guide = find(findings(grid, PAL), FAINT, WHITE)
    assert guide.examples[0] == "r0:   «│» palette = {"


def test_examples_are_capped_and_numbered_by_row():
    grid = [pad(cells("│", fg=FAINT) + cells("a")) for _ in range(5)]
    guide = find(findings(grid, PAL), FAINT, WHITE)
    assert len(guide.examples) == 3
    assert [e.split(":")[0] for e in guide.examples] == ["r0", "r1", "r2"]


def test_long_lines_are_windowed_around_the_marker():
    line = "x" * 90 + "Z"
    grid = [cells(line[:90]) + cells("Z", fg=FAINT)]
    got = find(findings(grid, PAL), FAINT, WHITE).examples[0]
    assert "«Z»" in got
    assert got.startswith("r0: …")


# -- runs -------------------------------------------------------------------

def test_sample_is_a_contiguous_run_not_a_row_wide_concatenation():
    # Two separate guides in one row must not be reported as the sample "││".
    grid = [pad(cells("│", fg=FAINT) + cells("ab") + cells("│", fg=FAINT))]
    guide = find(findings(grid, PAL), FAINT, WHITE)
    assert guide.sample == "│"
    assert guide.count == 2


# -- summarise --------------------------------------------------------------

def test_summarise_scores_text_and_counts_decorative_apart():
    grid = [
        pad(cells("│││", fg=FAINT)),                    # decorative
        pad(cells("readable", fg=(205, 205, 205))),     # text, also poor
    ]
    s = summarise(findings(grid, PAL))
    assert s["below_4_5"] == 1
    assert s["decorative"] == 1


def test_strict_folds_decorative_back_into_the_scoring():
    grid = [pad(cells("│││", fg=FAINT))]
    loose = summarise(findings(grid, PAL))
    strict = summarise(findings(grid, PAL), strict=True)
    assert loose["below_4_5"] == 0
    assert strict["below_4_5"] == 1


def test_worst_ignores_decorative_pairs():
    # The whole point: an indent guide must not become a fixture's headline.
    grid = [
        pad(cells("│", fg=(250, 250, 250))),   # nearly invisible, decorative
        pad(cells("text", fg=(120, 120, 120))),
    ]
    s = summarise(findings(grid, PAL))
    assert s["worst"] > 3.0


def test_summarise_of_nothing_does_not_explode():
    s = summarise([])
    assert s["below_4_5"] == 0 and s["decorative"] == 0


# -- a cell may hold more than one codepoint --------------------------------

MARKED = "á̖"    # one cell, three codepoints: pyte composes marks
                            # that do not compose onto the preceding cell


def one_cell(text, fg=INK, bg=WHITE):
    return [RGBCell(text, fg, bg, ColorKind.TRUECOLOR, ColorKind.DEFAULT,
                    False, False)]


def test_a_multi_codepoint_cell_does_not_shift_the_rest_of_the_row():
    # Slicing the row by cell index drifts by two the moment MARKED appears,
    # so the run after it gets sampled as the wrong text.
    grid = [pad(one_cell(MARKED, fg=FAINT) + cells("word", fg=INK))]
    # rstrip because pad's spaces share the run's colour; a two-cell drift
    # would leave "rd" here, not "word".
    assert find(findings(grid, PAL), INK, WHITE).sample.rstrip() == "word"


def test_a_multi_codepoint_cell_keeps_its_own_run_intact():
    grid = [pad(one_cell(MARKED, fg=FAINT) + cells("word", fg=INK))]
    assert find(findings(grid, PAL), FAINT, WHITE).sample == MARKED
