"""Fixture definitions: which programmes to capture and how.

Full-screen TUIs (fzf, atuin, zellij) still to land; helix and the fish
fixtures already drive keystrokes.
"""
from dataclasses import dataclass, field

# Pinned deliberately.  A HEAD-relative range drifts with every commit --
# including this harness's own -- and `git diff HEAD~3 -- modules/` currently
# produces nothing at all.  02e818f is "(hypr): Export GSETTINGS_SCHEMA_DIR",
# which touches modules/hyprland.nix.
DIFF_REV = "02e818f"


@dataclass(frozen=True)
class Fixture:
    name: str
    argv: list[str]
    keys: list[tuple[int, bytes]] = field(default_factory=list)
    cols: int = 100
    rows: int = 30
    timeout_s: float = 15.0
    # Variables to blank so the fixture cannot inherit live-session theming.
    scrub: tuple[str, ...] = ()
    note: str = ""


FIXTURES: tuple[Fixture, ...] = (
    Fixture(
        "rg-matches",
        ["rg", "--color=always", "palette", "modules/"],
        note="ripgrep: pure basic ANSI, so it exercises the palette path",
    ),
    Fixture(
        "eza-long",
        ["eza", "-laa", "--icons=always", "--color=always",
         "--color-scale=all", "--group", "--header", "modules/"],
        # NOT reproducible across tree states: --color-scale=all grades rows by
        # size and mtime, so editing anything under modules/ shifts the gradient
        # and the pair counts move with it (verified -- a commit to
        # terminal.nix took this from 14 sub-AA pairs to 13). The ratios are
        # real, but treat the counts as approximate rather than diffable.
        note="eza: ANSI plus Nerd Font icons; size/mtime gradient, so counts "
             "shift as the tree changes",
    ),
    Fixture(
        "bat-nix",
        ["bat", "--paging=never", "--color=always", "modules/theme.nix"],
        note="bat: all truecolour from its own Catppuccin theme",
    ),
    Fixture(
        "delta-diff",
        ["sh", "-c", f"git show {DIFF_REV} -- modules/ | delta"],
        rows=36,
        note="delta: truecolour, deliberately themed OneHalf* not Catppuccin",
    ),
    Fixture(
        "helix-edit",
        ["hx", "modules/theme.nix"],
        # Give helix time to draw, then move into the indented palette block:
        # that puts the cursorline and cursorcolumn over real code and brings
        # the indent guides into frame.  The keystroke also resets the quiet
        # timer, so the capture is the redraw rather than the opening screen.
        keys=[(1800, b"20j")],
        timeout_s=25.0,
        note="helix: its own truecolour theme, plus cursorline, cursorcolumn, "
             "indent guides, ruler and the mode-coloured statusline",
    ),
    # One grammar exercises one scope-to-colour mapping, so the languages are
    # separate fixtures.  Nix is covered by helix-edit above.  Each jumps far
    # enough in to fill the frame with real content rather than a file header.
    Fixture(
        "helix-python",
        ["hx", "tools/contrast-audit/contrast_audit/report.py"],
        keys=[(1800, b"45j")],
        timeout_s=25.0,
        note="helix + python: docstrings, comments, decorators, hex literals",
    ),
    Fixture(
        "helix-markdown",
        ["hx", "docs/26.05-pinned-defaults.md"],
        keys=[(1800, b"12j")],
        timeout_s=25.0,
        note="helix + markdown: headings, links, code spans, emphasis, lists",
    ),
    Fixture(
        "helix-c",
        ["hx", "files/swaylock/effect-blue-filter/filter.c"],
        keys=[(1800, b"8j")],
        timeout_s=25.0,
        note="helix + c: preprocessor directives, types, numeric literals",
    ),
    Fixture(
        "fish-syntax",
        ["fish", "-i"],
        keys=[(700, b'echo "hi" > /tmp/x --flag; nosuchcmd $HOME')],
        rows=12,
        note="fish syntax highlighting: quotes, redirection, invalid command",
    ),
)


def by_name(names: list[str] | None) -> list[Fixture]:
    if not names:
        return list(FIXTURES)
    known = {f.name: f for f in FIXTURES}
    unknown = [n for n in names if n not in known]
    if unknown:
        raise SystemExit(
            f"unknown fixture(s): {', '.join(unknown)}\n"
            f"known: {', '.join(sorted(known))}"
        )
    return [known[n] for n in names]
