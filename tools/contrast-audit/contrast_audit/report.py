"""Reduce a resolved grid to ranked contrast findings.

Each finding carries the layer that could fix it, because that is what the
audit exists to decide.  The split is three-way rather than
palette-versus-application: every programme catppuccin/nix themes ships hex
colour files, so a two-way split would file them all under "needs a per-app
override" when in fact they all move together from one setting.
"""
from collections import Counter
from dataclasses import dataclass

from contrast_audit.palette import RGB, Palette, contrast_ratio, lightness_delta
from contrast_audit.resolve import ColorKind, RGBCell

_ANSI_KINDS = (ColorKind.DEFAULT, ColorKind.ANSI, ColorKind.CUBE)
_SAMPLE_LIMIT = 40
_EXAMPLE_LIMIT = 3

TIER_ANSI = "ansi"
TIER_CATPPUCCIN = "catppuccin"
TIER_FOREIGN = "foreign"

# What the pair is for, which decides whether its ratio is a defect.  A
# contrast ratio only means something if there is a reading task: line numbers
# are text you look up, whereas an indent guide is a spatial hint that is
# redundant with the indentation you can already see, and a statusline's
# padding carries nothing at all.  WCAG draws the same line -- 4.5:1 for text,
# 3:1 for meaningful graphics, no requirement for decorative or redundant ones.
ROLE_TEXT = "text"
ROLE_GUIDE = "guide"
ROLE_BACKGROUND = "background"
DECORATIVE_ROLES = (ROLE_GUIDE, ROLE_BACKGROUND)

# Measured, not chosen.  contrast_audit.calibrate printed ramps at known
# lightness delta in both flavours, unfiltered, and these are where reading
# stopped: BODY is "would read a screenful of this without noticing the
# contrast", GLANCE is "can pull it correctly when I look, but would not want
# to read anything at it".  Both flavours landed within 0.01 of each other on
# body, which is why one pair of numbers covers Latte and Frappe.
#
# They classify all ten independently judged pairs correctly -- body text at
# 0.52, comments at 0.25, helix's line numbers at 0.13-0.15 ("readable
# enough"), fzf's green on its selected row at 0.078 ("really low"), eza's pale
# end at 0.060 ("unreadable") -- which the WCAG ratio does not: those last two
# sit at 1.48:1 and 1.16:1, within 0.3 of pairs called fine.
#
# A chroma correction was fitted and rejected.  Both flavours' body marks agree
# on sqrt(dL^2 + (0.8*dab)^2), and it is wrong: it scores fzf's green 0.181
# against the neighbouring grey's 0.212, near-equal, for pairs judged "really
# low" and "okay".  The body marks were the least confident ones and the fit was
# reading their noise.  The confident tier fits a coefficient of 0.0-0.3, so
# plain lightness delta is what is used.
BODY_DELTA_L = 0.22
GLANCE_DELTA_L = 0.07


def required_delta_l(role: str) -> float:
    """The lightness delta this role has to clear to be doing its job.

    Guides get the lower bar on purpose.  A separator that reads as quietly as
    body text is a separator competing with the text, so the goal for structure
    is to clear legibility and stop -- which is also why the two grey slots
    nearest the background are deliberately left below body.
    """
    if role == ROLE_TEXT:
        return BODY_DELTA_L
    return GLANCE_DELTA_L if role == ROLE_GUIDE else 0.0

_GUIDE_RANGES = (
    (0x2500, 0x257F),  # box drawing: indent guides, borders, separators
    (0x2580, 0x259F),  # block elements: the thin bars used as guides
    (0x2400, 0x243F),  # control pictures: rendered whitespace
    (0xE0B0, 0xE0D4),  # powerline separators (private use)
)
# Deliberately no ASCII "|": it is an operator in most of the languages the
# fixtures display, so treating it as a guide would hide real text.
_GUIDE_CHARS = frozenset("·")  # middle dot, used for rendered whitespace


def is_guide(ch: str) -> bool:
    """True for glyphs that draw structure rather than say anything."""
    if ch in _GUIDE_CHARS:
        return True
    cp = ord(ch)
    return any(lo <= cp <= hi for lo, hi in _GUIDE_RANGES)


def role_for(has_text: bool, has_glyph: bool) -> str:
    if has_text:
        return ROLE_TEXT
    return ROLE_GUIDE if has_glyph else ROLE_BACKGROUND


@dataclass(frozen=True)
class Finding:
    fg: RGB
    bg: RGB
    ratio: float
    # OKLCH lightness difference, and the one to judge by: the ratio is
    # luminance-only and so overstates saturated colours.  Thresholds are
    # BODY_DELTA_L and GLANCE_DELTA_L above, calibrated rather than assumed.
    delta_l: float
    count: int
    sample: str
    tier: str
    token: str | None
    dim: bool = False
    role: str = ROLE_TEXT
    # Up to _EXAMPLE_LIMIT rendered contexts, so a reader can tell what the
    # pair actually is instead of inferring it from two hex values.
    examples: tuple[str, ...] = ()


def fix_tier(cell: RGBCell, palette: Palette) -> str:
    """Which layer can fix this cell's foreground.

    ansi       -- one edit in programs.kitty.settings, reaching every
                  ANSI-emitting programme at once.
    catppuccin -- a Catppuccin token, so it moves with catppuccin.flavor.
                  Still one setting, not one override per programme.
    foreign    -- themed outside Catppuccin; no palette or flavour change
                  reaches it.
    """
    if cell.fg_kind in _ANSI_KINDS:
        return TIER_ANSI
    return TIER_CATPPUCCIN if palette.token_for(cell.fg) else TIER_FOREIGN


def page_background(grid: list[list[RGBCell]]) -> RGB | None:
    """The most common background, i.e. the page's own backdrop.

    Derived from the grid rather than the palette so it stays correct when
    backgrounds have been composited against a backdrop.
    """
    counts = Counter(c.bg for row in grid for c in row)
    return counts.most_common(1)[0][0] if counts else None


def excerpt(row: int, line: str, start: int, end: int, width: int = 56) -> str:
    """One occurrence in context, with the run itself marked by guillemets."""
    marked = (line[:start] + "«" + line[start:end] + "»"
              + line[end:]).rstrip()
    if len(marked) <= width:
        return f"r{row}: {marked}"
    lo = max(0, min(start - 12, len(marked) - width))
    frag = marked[lo:lo + width]
    return (f"r{row}: {'…' if lo else ''}{frag}"
            f"{'…' if lo + width < len(marked) else ''}")


def findings(grid: list[list[RGBCell]], palette: Palette) -> list[Finding]:
    """Group cells by (foreground, background), worst contrast first.

    Walks contiguous runs rather than single cells so that `sample` and
    `examples` show text as it actually appears, instead of concatenating every
    same-coloured fragment scattered across a row.

    A blank run is kept when its background differs from the page background:
    statuslines, tab bars, selections and cursorlines are mostly spaces whose
    meaning lives entirely in the background, and dropping them would hide most
    of the chrome in the full-screen fixtures.  Those land in ROLE_BACKGROUND.
    """
    page_bg = page_background(grid)
    groups: dict[tuple[RGB, RGB, str, bool], dict] = {}

    for y, raw in enumerate(grid):
        # Drop double-width stubs so column offsets match the rendered line.
        cells = [c for c in raw if c.char != ""]
        line = "".join(c.char for c in cells)
        keys = [(c.fg, c.bg, fix_tier(c, palette), c.dim) for c in cells]
        # Where each cell starts in `line`.  A cell's char is usually one
        # codepoint but need not be: pyte's draw() composes a combining mark
        # onto the previous cell via last._replace(data=NFC(last.data + char)),
        # so a base letter with marks that do not compose leaves one cell
        # holding several.  Indexing `line` by cell number then drifts for the
        # rest of the row, and runs get sampled and classified as the wrong
        # text.
        offs = [0]
        for c in cells:
            offs.append(offs[-1] + len(c.char))

        start = 0
        while start < len(cells):
            end = start + 1
            while end < len(cells) and keys[end] == keys[start]:
                end += 1
            run = line[offs[start]:offs[end]]
            if run.strip() or cells[start].bg != page_bg:
                entry = groups.setdefault(keys[start], {
                    "count": 0, "sample": "", "examples": [],
                    "has_text": False, "has_glyph": False,
                    "token": palette.token_for(cells[start].fg),
                })
                entry["count"] += end - start
                if len(run) > len(entry["sample"]):
                    entry["sample"] = run[:_SAMPLE_LIMIT]
                glyphs = [ch for ch in run if ch.strip()]
                entry["has_glyph"] |= bool(glyphs)
                entry["has_text"] |= any(not is_guide(ch) for ch in glyphs)
                if len(entry["examples"]) < _EXAMPLE_LIMIT:
                    entry["examples"].append(
                        excerpt(y, line, offs[start], offs[end]))
            start = end

    out = [
        Finding(fg=fg, bg=bg, ratio=contrast_ratio(fg, bg),
                delta_l=lightness_delta(fg, bg), count=v["count"],
                sample=v["sample"], tier=tier, token=v["token"], dim=dim,
                role=role_for(v["has_text"], v["has_glyph"]),
                examples=tuple(v["examples"]))
        for (fg, bg, tier, dim), v in groups.items()
    ]
    return sorted(out, key=lambda f: f.ratio)


def summarise(items: list[Finding], *, strict: bool = False) -> dict:
    """Counts used by the sweep summary and the index page.

    Scored over ROLE_TEXT only, because the headline numbers are read as "how
    much of this is unreadable" and a decorative pair would otherwise become a
    fixture's `worst` -- ranking an indent guide above real prose. Decorative
    pairs are still counted, in `decorative`, and `strict` folds them back into
    the scoring for anyone who wants the unfiltered view.
    """
    scored = items if strict else [f for f in items if f.role == ROLE_TEXT]
    below45 = [f for f in scored if f.ratio < 4.5]
    # Judged per role, so a guide is not reported as failing a bar it was never
    # meant to clear.  `items` rather than `scored`: guides are excluded from
    # the ratio scoring precisely because the ratio has no role model, but they
    # do have a delta bar of their own and it is worth counting.
    short = [f for f in items if f.delta_l < required_delta_l(f.role)]
    return {
        "pairs": len(scored),
        "below_4_5": len(below45),
        "below_3": sum(1 for f in scored if f.ratio < 3.0),
        "worst": min((f.ratio for f in scored), default=float("nan")),
        # The lightness delta of the worst-ratio pair, not the smallest delta:
        # the point is to see what the headline ratio corresponds to
        # perceptually, so they have to describe the same pair.
        "worst_delta_l": min(scored, key=lambda f: f.ratio).delta_l
        if scored else float("nan"),
        # The actual defect count, by the calibrated measure.
        "below_body": sum(1 for f in scored if f.delta_l < BODY_DELTA_L),
        "below_glance": sum(1 for f in scored if f.delta_l < GLANCE_DELTA_L),
        "short_for_role": len(short),
        "worst_delta": min((f.delta_l for f in scored), default=float("nan")),
        "tiers": {
            tier: sum(1 for f in below45 if f.tier == tier)
            for tier in (TIER_ANSI, TIER_CATPPUCCIN, TIER_FOREIGN)
        },
        "decorative": sum(1 for f in items
                          if f.role in DECORATIVE_ROLES and f.ratio < 4.5),
    }
