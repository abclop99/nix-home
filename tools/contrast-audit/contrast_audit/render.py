"""Render a resolved grid to a self-contained HTML page.

HTML rather than a raster image: the browser handles layout and font
fallback, so double-width Nerd Font icons and missing glyphs are not our
problem, colours are exact, and the same file is both viewable by a human and
screenshottable by a headless browser.

No external resources of any kind, so the page works offline and can be
published as an artifact.
"""
from html import escape

from contrast_audit.palette import RGB, Palette, rgb_to_hex
from contrast_audit.report import DECORATIVE_ROLES, Finding, ROLE_TEXT
from contrast_audit.resolve import RGBCell


def _pair_id(fg: RGB, bg: RGB) -> str:
    """Stable key linking a findings row to the cells it describes."""
    return f"{rgb_to_hex(fg)[1:]}{rgb_to_hex(bg)[1:]}"

PAGE_CSS = """
:root { color-scheme: light dark; }
body { font-family: system-ui, -apple-system, sans-serif; margin: 0;
       padding: 2rem; background: #1b1b1f; color: #e8e8ea; }
h1 { font-size: 1.15rem; font-weight: 600; margin: 0 0 0.25rem; }
.meta { font-size: 0.8rem; opacity: 0.65; margin-bottom: 1.25rem; }
.term { font-family: "FiraCode Nerd Font Mono", "FiraCode Nerd Font",
        "Fira Code", ui-monospace, monospace;
        font-size: 13px; line-height: 1.25; display: inline-block;
        padding: 10px 12px; white-space: pre; border-radius: 6px;
        overflow-x: auto; max-width: 100%; }
.row { height: 1.25em; }
h2 { font-size: 0.95rem; margin: 1.75rem 0 0.5rem; font-weight: 600; }
table { border-collapse: collapse; font-size: 12px; }
th, td { border: 1px solid #ffffff22; padding: 3px 9px; text-align: left;
         white-space: nowrap; }
th { font-weight: 600; opacity: 0.8; }
td.num { text-align: right; font-variant-numeric: tabular-nums; }
.sw { font-family: "FiraCode Nerd Font Mono", ui-monospace, monospace;
      padding: 1px 6px; border-radius: 3px; }
.fail { color: #ff8080; font-weight: 600; }
.warn { color: #ffc266; }
.ok { opacity: 0.55; }
.tier-ansi { color: #7ee787; }
.tier-catppuccin { color: #a6a6ff; }
.tier-foreign { color: #ff9e64; }
.hint { font-size: 0.8rem; opacity: 0.6; max-width: 68ch; margin: 0.4rem 0; }
td.dl { opacity: 0.7; }
tbody tr[data-p] { cursor: pointer; }
tbody tr[data-p]:hover { background: #ffffff10; }
tr.sel { background: #ffffff22; outline: 1px solid #ffffff55; }
.term .hl { outline: 2px solid #ff3b3b; outline-offset: -1px; }
td.ex { white-space: pre; font-family: ui-monospace, monospace; font-size: 11px;
        opacity: 0.75; }
"""


def _grade(ratio: float) -> str:
    if ratio < 3.0:
        return "fail"
    if ratio < 4.5:
        return "warn"
    return "ok"


def _span(style: tuple[RGB, RGB, bool], chars: list[str]) -> str:
    fg, bg, bold = style
    weight = ";font-weight:700" if bold else ""
    return (f'<span data-p="{_pair_id(fg, bg)}" '
            f'style="color:{rgb_to_hex(fg)};background:{rgb_to_hex(bg)}{weight}">'
            f"{escape(''.join(chars))}</span>")


def _render_row(row: list[RGBCell]) -> str:
    parts: list[str] = []
    run: list[str] = []
    style: tuple | None = None
    for c in row:
        if c.char == "":
            continue  # double-width stub: the glyph already spans this column
        this = (c.fg, c.bg, c.bold)
        if this != style and run:
            parts.append(_span(style, run))
            run = []
        style = this
        run.append(c.char)
    if run:
        parts.append(_span(style, run))
    return '<div class="row">' + "".join(parts) + "</div>"


def _finding_rows(items: list[Finding]) -> str:
    rows = []
    for f in items:
        sample = escape(f.sample[:24]) or "&nbsp;&nbsp;&nbsp;"
        examples = "<br>".join(escape(e) for e in f.examples)
        rows.append(
            f"<tr data-p='{_pair_id(f.fg, f.bg)}'>"
            f"<td><span class='sw' style='color:{rgb_to_hex(f.fg)};"
            f"background:{rgb_to_hex(f.bg)}'>{sample}</span></td>"
            f"<td class='num {_grade(f.ratio)}'>{f.ratio:.2f}</td>"
            f"<td class='num dl'>{f.delta_l:.3f}</td>"
            f"<td class='num'>{f.count}</td>"
            f"<td class='tier-{f.tier}'>{f.tier}</td>"
            f"<td>{escape(f.token or '')}</td>"
            f"<td>{rgb_to_hex(f.fg)} on {rgb_to_hex(f.bg)}"
            f"{' (dim)' if f.dim else ''}</td>"
            f"<td class='ex'>{examples}</td>"
            f"</tr>"
        )
    return (
        "<table><thead><tr><th>sample</th><th>ratio</th><th title='OKLCH "
        "lightness difference: perceptually uniform, so comparable across hues "
        "where the ratio is not'>&Delta;L</th><th>cells</th>"
        "<th>fix tier</th><th>token</th><th>colours</th>"
        "<th>where it appears</th></tr></thead>"
        f"<tbody>{''.join(rows)}</tbody></table>"
    )


def _render_findings(items: list[Finding]) -> str:
    if not items:
        return "<h2>Findings</h2><p>No coloured text captured.</p>"
    text = [f for f in items if f.role == ROLE_TEXT]
    deco = [f for f in items if f.role in DECORATIVE_ROLES]

    out = ["<p class='hint'>Click any row to outline the cells it describes "
           "in the frame above.</p>"]
    out.append("<h2>Text — worst contrast first</h2>")
    out.append(_finding_rows(text) if text
               else "<p>No readable text captured.</p>")
    if deco:
        out.append(
            "<h2>Decorative — guides and backgrounds</h2>"
            "<p class='hint'>Listed separately because there is no reading "
            "task: indent guides are redundant with the indentation itself, "
            "and background-only pairs carry no glyph. Low ratios here are "
            "usually deliberate, not defects.</p>"
        )
        out.append(_finding_rows(deco))
    return "".join(out)


_HIGHLIGHT_JS = """
document.addEventListener('click', function (e) {
  var tr = e.target.closest('tr[data-p]');
  if (!tr) return;
  var already = tr.classList.contains('sel');
  document.querySelectorAll('tr.sel').forEach(function (t) {
    t.classList.remove('sel');
  });
  document.querySelectorAll('.term .hl').forEach(function (s) {
    s.classList.remove('hl');
  });
  if (already) return;
  tr.classList.add('sel');
  document.querySelectorAll('.term [data-p="' + tr.dataset.p + '"]')
    .forEach(function (s) { s.classList.add('hl'); });
});
"""


def render_comparison(panels: list[tuple[str, str, list[list[RGBCell]]]],
                      changes: list[tuple[str, RGB, RGB, float, float]],
                      title: str, palette: Palette, subtitle: str = "") -> str:
    """The same captured content under several palettes, stacked to compare.

    panels: (heading, caption, grid).  The caption carries that panel's own
    numbers, so a reader can judge by eye and by ratio in one pass.
    """
    term_bg = rgb_to_hex(palette.background)
    frames = "".join(
        f"<h2>{escape(heading)}</h2>"
        f"<div class='meta'>{escape(caption)}</div>"
        f"<div class='term' style='background:{term_bg}'>"
        + "".join(_render_row(row) for row in grid) + "</div>"
        for heading, caption, grid in panels
    )
    rows = "".join(
        f"<tr>"
        f"<td>{escape(tok)}</td>"
        f"<td><span class='sw' style='color:{rgb_to_hex(old)};"
        f"background:{term_bg}'>{escape(tok)}</span></td>"
        f"<td class='num {_grade(r_old)}'>{r_old:.2f}</td>"
        f"<td><span class='sw' style='color:{rgb_to_hex(new)};"
        f"background:{term_bg}'>{escape(tok)}</span></td>"
        f"<td class='num {_grade(r_new)}'>{r_new:.2f}</td>"
        f"<td>{rgb_to_hex(old)} → {rgb_to_hex(new)}</td>"
        f"</tr>"
        for tok, old, new, r_old, r_new in changes
    )
    table = (
        "<h2>Tokens moved</h2>"
        "<table><thead><tr><th>token</th><th>before</th><th>ratio</th>"
        "<th>after</th><th>ratio</th><th>hex</th></tr></thead>"
        f"<tbody>{rows}</tbody></table>"
    ) if changes else ""
    return (
        "<!doctype html><html><head><meta charset='utf-8'>"
        "<meta name='viewport' content='width=device-width,initial-scale=1'>"
        f"<title>{escape(title)}</title><style>{PAGE_CSS}</style></head>"
        f"<body><h1>{escape(title)}</h1>"
        f"<div class='meta'>{escape(subtitle)}</div>{frames}{table}</body></html>"
    )


def render_index(entries: list[dict]) -> str:
    """A local landing page linking every captured fixture.

    entries: {flavor, palette, lens, fixture, note, worst, below_4_5,
              below_3, tiers, href}
    """
    by_flavor: dict[str, list[dict]] = {}
    for e in entries:
        by_flavor.setdefault(e["flavor"], []).append(e)

    sections = []
    for flavor, rows in sorted(by_flavor.items()):
        body = "".join(
            f"<tr>"
            f"<td><a href='{e['href']}'>{escape(e['fixture'])}</a></td>"
            f"<td class='num {_grade(e['worst'])}'>{e['worst']:.2f}</td>"
            f"<td class='num dl'>{e.get('worst_delta_l', float('nan')):.3f}</td>"
            f"<td class='num'>{e['below_4_5']}</td>"
            f"<td class='num'>{e['below_3']}</td>"
            f"<td class='tier-ansi num'>{e['tiers']['ansi']}</td>"
            f"<td class='tier-catppuccin num'>{e['tiers']['catppuccin']}</td>"
            f"<td class='tier-foreign num'>{e['tiers']['foreign']}</td>"
            f"<td class='num deco'>{e.get('decorative', 0)}</td>"
            f"<td class='note'>{escape(e['note'])}</td>"
            f"</tr>"
            for e in sorted(rows, key=lambda r: r["worst"])
        )
        palette_name = rows[0]["palette"]
        sections.append(
            f"<h2>{escape(flavor)} — {escape(palette_name)}</h2>"
            f"<div class='meta'>lens: {escape(rows[0]['lens'])}</div>"
            "<table><thead><tr><th>fixture</th><th>worst</th><th>&Delta;L</th>"
            "<th>&lt;4.5</th>"
            "<th>&lt;3.0</th><th>ansi</th><th>catppuccin</th><th>foreign</th>"
            "<th>deco</th><th></th></tr></thead>"
            f"<tbody>{body}</tbody></table>"
        )

    legend = (
        "<h2>How to read the tiers</h2><ul class='legend'>"
        "<li><b class='tier-ansi'>ansi</b> — came from an ANSI slot. One edit "
        "in <code>programs.kitty.settings</code> fixes it everywhere at once.</li>"
        "<li><b class='tier-catppuccin'>catppuccin</b> — a Catppuccin token, so "
        "it moves with <code>catppuccin.flavor</code>. Still one setting.</li>"
        "<li><b class='tier-foreign'>foreign</b> — themed outside Catppuccin "
        "entirely. No palette or flavour change will ever reach it.</li>"
        "</ul>"
        "<h2>What the counts cover</h2><ul class='legend'>"
        "<li>Ratios are scored over <b>text</b> only — pairs carrying glyphs "
        "you actually read.</li>"
        "<li><b class='deco'>deco</b> counts pairs below 4.5:1 that are "
        "indent guides, separators or background-only chrome. They are "
        "excluded from the other columns because there is no reading task, so "
        "a low ratio there is usually a deliberate choice. Each fixture's page "
        "lists them in full.</li>"
        "<li><code>--strict</code> scores everything together instead.</li>"
        "<li><b>&Delta;L</b> is the OKLCH lightness difference, shown beside "
        "each ratio. The ratio is luminance-only, so it overstates saturated "
        "colours; &Delta;L is perceptually uniform and comparable across hues. "
        "For calibration against Latte's own base: body text is 0.52, quiet "
        "structure 0.25, and 0.15 is effectively invisible. No pass/fail bar is "
        "attached to it.</li>"
        "</ul>"
    )
    return (
        "<!doctype html><html><head><meta charset='utf-8'>"
        "<meta name='viewport' content='width=device-width,initial-scale=1'>"
        f"<title>Contrast audit</title><style>{PAGE_CSS}{_INDEX_CSS}</style>"
        "</head><body><h1>Theme contrast audit</h1>"
        "<div class='meta'>Counts are of distinct foreground/background pairs. "
        "Tier counts cover pairs below 4.5:1.</div>"
        f"{''.join(sections)}{legend}</body></html>"
    )


_INDEX_CSS = """
a { color: #8ab4ff; }
h2 { margin-top: 2rem; }
ul.legend { font-size: 0.85rem; line-height: 1.7; max-width: 60ch; }
code { background: #ffffff14; padding: 1px 4px; border-radius: 3px; }
td.note { white-space: normal; opacity: 0.6; font-size: 11px; max-width: 40ch; }
.deco { color: #9aa0a6; }
"""


def render_html(
    grid: list[list[RGBCell]],
    items: list[Finding],
    title: str,
    palette: Palette | None = None,
    subtitle: str = "",
) -> str:
    body = "".join(_render_row(row) for row in grid)
    term_bg = rgb_to_hex(palette.background) if palette else "#000000"
    meta = escape(subtitle) if subtitle else ""
    return (
        "<!doctype html><html><head><meta charset='utf-8'>"
        "<meta name='viewport' content='width=device-width,initial-scale=1'>"
        f"<title>{escape(title)}</title><style>{PAGE_CSS}</style></head>"
        f"<body><h1>{escape(title)}</h1>"
        f"<div class='meta'>{meta}</div>"
        f"<div class='term' style='background:{term_bg}'>{body}</div>"
        f"{_render_findings(items)}"
        f"<script>{_HIGHLIGHT_JS}</script></body></html>"
    )
