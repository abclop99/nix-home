"""Sweep orchestration: capture each fixture under a variant and report."""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from contrast_audit.candidate import ACCENTS, adjust_tokens, remap_grid
from contrast_audit.drive import DriveError, drive
from contrast_audit.emulate import emulate
from contrast_audit.fixtures import FIXTURES, Fixture, by_name
from contrast_audit.palette import (
    Palette,
    contrast_ratio,
    hex_to_rgb,
    load_palette,
)
from contrast_audit.render import render_comparison, render_html, render_index
from contrast_audit.report import findings, summarise
from contrast_audit.resolve import resolve_grid

VARIANTS = {"latte": "light", "frappe": "dark"}
_SET_GX = re.compile(r"^set -gx (\w+) '(.*)'$", re.M)


def _variant_root(repo: Path, specialisation: str) -> Path:
    root = repo / "result/specialisation" / specialisation
    if not (root / "home-files/.config").is_dir():
        raise SystemExit(
            f"{root}/home-files/.config missing -- run hm-build first so the "
            "variant configs exist"
        )
    return root


def _session_vars(root: Path) -> dict[str, str]:
    """Variables home-manager sets per variant that are not config files.

    These live in home-path/etc/profile.d, NOT under home-files, and fzf's
    colours exist nowhere else -- inheriting them from the live session would
    render one variant's fzf in the other variant's colours.
    """
    path = root / "home-path/etc/profile.d/hm-session-vars.fish"
    if not path.exists():
        return {}
    return dict(_SET_GX.findall(path.read_text()))


def _prepare_config(root: Path, workdir: Path) -> tuple[Path, Path]:
    """Copy the variant's config somewhere writable and build bat's cache.

    The specialisation tree is a store path (mode 0555, owned by root), but
    fish writes fish_variables into its config dir and atuin and zellij touch
    theirs -- those failures would land in the captured frame as fake
    findings.  bat additionally cannot use a .tmTheme until `bat cache
    --build` compiles it, which home-manager only does at activation, so a
    build tree has the theme file but no cache and bat silently falls back to
    its built-in default under BOTH variants.
    """
    config = workdir / "config"
    cache = workdir / "cache"
    shutil.copytree(root / "home-files/.config", config, symlinks=False)
    cache.mkdir(parents=True, exist_ok=True)
    for path in config.rglob("*"):
        path.chmod(path.stat().st_mode | 0o200)
    config.chmod(config.stat().st_mode | 0o200)

    if (config / "bat").is_dir():
        subprocess.run(
            ["bat", "cache", "--build"],
            env={**os.environ, "XDG_CONFIG_HOME": str(config),
                 "XDG_CACHE_HOME": str(cache)},
            capture_output=True, timeout=60,
        )
    return config, cache


def _fixture_env(config: Path, cache: Path, session: dict[str, str]) -> dict[str, str]:
    env = {
        "XDG_CONFIG_HOME": str(config),
        "XDG_CACHE_HOME": str(cache),
        "XDG_DATA_HOME": str(cache / "data"),
        # zellij ignores XDG_CONFIG_HOME entirely (verified).
        "ZELLIJ_CONFIG_DIR": str(config / "zellij"),
        # Otherwise delta is captured through less and we get less's viewport.
        "PAGER": "cat",
        "GIT_PAGER": "cat",
    }
    for var in ("FZF_DEFAULT_OPTS", "EZA_COLORS"):
        if var in session:
            env[var] = session[var]
    # STARSHIP_CONFIG is pinned to the live path in both variants; point it at
    # the variant copy for correctness even though the file is identical.
    if (config / "starship.toml").exists():
        env["STARSHIP_CONFIG"] = str(config / "starship.toml")
    return env


def _capture(fixture: Fixture, env: dict[str, str], repo: Path, palette: Palette,
             backdrop, model_dim: bool):
    data = drive(fixture.argv, keys=fixture.keys, cols=fixture.cols,
                 rows=fixture.rows, env=env, cwd=str(repo),
                 timeout_s=fixture.timeout_s,
                 foreground=palette.foreground, background=palette.background)
    cells = emulate(data, fixture.cols, fixture.rows)
    grid = resolve_grid(cells, palette, model_dim=model_dim, backdrop=backdrop)
    return grid, findings(grid, palette)


def _caption(found, strict: bool) -> str:
    """One panel's own numbers, so before/after can be read off the page.

    Without this the comparison shows two frames and a token table, and the
    reader has to eyeball whether the move actually bought anything.
    """
    s = summarise(found, strict=strict)
    return (f"worst {s['worst']:.2f}:1 · {s['below_4_5']} pairs below AA · "
            f"{s['below_3']} below 3:1")


def _screenshot(html: Path, png: Path, width: int = 1500, height: int = 900) -> bool:
    try:
        subprocess.run(
            ["chromium", "--headless=new", "--no-sandbox", "--disable-gpu",
             "--force-color-profile=srgb", "--hide-scrollbars",
             f"--window-size={width},{height}",
             f"--screenshot={png}", f"file://{html}"],
            capture_output=True, timeout=120, check=True,
        )
        return png.exists()
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired,
            FileNotFoundError):
        return False


def main(argv=None):
    parser = argparse.ArgumentParser(prog="contrast-audit")
    parser.add_argument("--version", action="version", version="0.1")
    parser.add_argument("--flavor", choices=sorted(VARIANTS), default="latte")
    parser.add_argument("--repo", type=Path,
                        default=Path("/home/abclop99/.config/home-manager"))
    parser.add_argument("--out", type=Path, default=None,
                        help="output directory (default <repo>/audit)")
    parser.add_argument("--fixture", action="append",
                        help="run only these fixtures (repeatable)")
    parser.add_argument("--backdrop", metavar="HEX", default=None,
                        help="model kitty's background_opacity against this "
                             "colour, e.g. '#101010' for a dark desktop")
    parser.add_argument("--no-dim", action="store_true",
                        help="do not model kitty's dim_opacity")
    parser.add_argument("--config-from", choices=("light", "dark"), default=None,
                        help="take the programmes' config from this variant "
                             "while measuring against --flavor's palette. "
                             "Models a long-running TUI that cached one "
                             "flavour's theme before darkman switched the "
                             "terminal to the other")
    parser.add_argument("--candidate", type=float, metavar="RATIO", default=None,
                        help="also write a before/after page per fixture, with "
                             "the accent tokens moved just far enough to clear "
                             "RATIO against the background (try 4.5). Direction "
                             "follows the background: darker on a light one, "
                             "lighter on a dark one")
    parser.add_argument("--strict", action="store_true",
                        help="score decorative pairs (indent guides, "
                             "separators, background-only chrome) alongside "
                             "text instead of listing them separately")
    parser.add_argument("--screenshot", action="store_true",
                        help="also render each page to PNG via headless chromium")
    args = parser.parse_args(argv)

    repo = args.repo.resolve()
    out_dir = (args.out or repo / "audit") / args.flavor
    out_dir.mkdir(parents=True, exist_ok=True)

    root = _variant_root(repo, VARIANTS[args.flavor])
    palette = load_palette(root / "home-files/.config/kitty/kitty.conf",
                           flavor=args.flavor)
    # The palette always comes from --flavor (that is the terminal we are
    # measuring against); only the programmes' own config can be taken from
    # the other variant.
    config_root = (_variant_root(repo, args.config_from) if args.config_from
                   else root)
    backdrop = hex_to_rgb(args.backdrop) if args.backdrop else None

    lens = []
    if backdrop and palette.background_opacity < 1.0:
        lens.append(f"background_opacity {palette.background_opacity} "
                    f"over {args.backdrop}")
    if not args.no_dim and palette.dim_opacity < 1.0:
        lens.append(f"dim_opacity {palette.dim_opacity}")
    lens_text = "; ".join(lens) or "theme colours as specified"

    print(f"palette: {palette.name}  fg={palette.foreground} bg={palette.background}")
    print(f"lens:    {lens_text}")
    print(f"scored:  {'everything' if args.strict else 'text only'} "
          f"(decorative pairs {'included' if args.strict else 'listed apart'})")
    print(f"{'fixture':<24} {'worst':>6} {'dL':>6} {'<4.5':>5} {'<3.0':>5} "
          f"{'deco':>5}  tiers (of <4.5)")

    # Hoisted: nothing here varies per fixture, and each call bisects fourteen
    # accents through a conversion that may itself bisect on chroma.
    subs, changes = {}, []
    if args.candidate:
        moved = adjust_tokens(palette.tokens, palette.background,
                              args.candidate, only=ACCENTS)
        subs = {palette.tokens[t]: new for t, new in moved.items()}
        changes = sorted(
            ((t, palette.tokens[t], new,
              contrast_ratio(palette.tokens[t], palette.background),
              contrast_ratio(new, palette.background))
             for t, new in moved.items()),
            key=lambda c: c[3],
        )

    failures = []
    entries: list[dict] = []
    with tempfile.TemporaryDirectory(prefix="contrast-audit-") as tmp:
        config, cache = _prepare_config(config_root, Path(tmp))
        session = _session_vars(config_root)
        base_env = _fixture_env(config, cache, session)

        for fixture in by_name(args.fixture):
            env = dict(base_env)
            for key in fixture.scrub:
                env[key] = ""
            try:
                grid, found = _capture(fixture, env, repo, palette, backdrop,
                                       not args.no_dim)
            except DriveError as exc:
                failures.append((fixture.name, str(exc)))
                print(f"{fixture.name:<24} FAILED: {exc}")
                continue

            html = out_dir / f"{fixture.name}.html"
            html.write_text(
                render_html(grid, found, f"{fixture.name} — {palette.name}",
                            palette=palette,
                            subtitle=f"{fixture.note} · lens: {lens_text}"),
                encoding="utf-8",
            )
            if args.screenshot and not _screenshot(
                    html, out_dir / f"{fixture.name}.png"):
                print(f"{fixture.name:<24} screenshot failed", file=sys.stderr)

            if args.candidate:
                after = remap_grid(grid, subs)
                cmp_html = out_dir / f"{fixture.name}-candidate.html"
                cmp_html.write_text(
                    render_comparison(
                        [("As it is now", _caption(found, args.strict), grid),
                         ("With the accents moved",
                          _caption(findings(after, palette), args.strict),
                          after)],
                        changes,
                        f"{fixture.name} — {palette.name} vs candidate",
                        palette=palette,
                        subtitle=f"accents moved to clear "
                                 f"{args.candidate}:1 on "
                                 f"{palette.name.split('-')[-1]} base; "
                                 f"greys left alone",
                    ),
                    encoding="utf-8",
                )
                if args.screenshot and not _screenshot(
                        cmp_html, out_dir / f"{fixture.name}-candidate.png",
                        height=1800):
                    print(f"{fixture.name:<24} candidate screenshot failed",
                          file=sys.stderr)

            s = summarise(found, strict=args.strict)
            entries.append({
                "flavor": args.flavor,
                "palette": palette.name,
                "lens": lens_text,
                "fixture": fixture.name,
                "note": fixture.note,
                "href": f"{args.flavor}/{fixture.name}.html",
                "worst": s["worst"],
                "worst_delta_l": s["worst_delta_l"],
                "below_4_5": s["below_4_5"],
                "below_3": s["below_3"],
                "tiers": s["tiers"],
                "decorative": s["decorative"],
            })
            tiers = " ".join(f"{k}={v}" for k, v in s["tiers"].items())
            print(f"{fixture.name:<24} {s['worst']:6.2f} "
                  f"{s['worst_delta_l']:6.3f} {s['below_4_5']:5} "
                  f"{s['below_3']:5} {s['decorative']:5}  {tiers}")

    entries = _merge_summary(out_dir, entries)
    (out_dir / "summary.json").write_text(json.dumps(entries, indent=2))
    index = _write_index(out_dir.parent)

    print(f"\nwrote {out_dir}")
    print(f"open {index}")
    if failures:
        print(f"{len(failures)} fixture(s) failed", file=sys.stderr)
        return 1
    return 0


def _merge_summary(out_dir: Path, fresh: list[dict]) -> list[dict]:
    """Fold this run's entries into the flavour's existing summary.

    A --fixture run measures a subset, and writing it out flat dropped every
    other fixture from the index while leaving its page on disk unreferenced --
    the table then reads as the current state of the sweep when it is a slice
    of one.

    Entries measured under a different palette or lens are discarded rather
    than kept, because the index presents one table per flavour and mixing two
    lenses in it gives the reader no way to tell which row is which.
    """
    path = out_dir / "summary.json"
    if not path.exists():
        return fresh
    stored = json.loads(path.read_text())
    if not fresh:
        # Every fixture failed. main already reports that and exits non-zero;
        # blanking the page on top of it would lose the last good sweep too.
        return stored
    same = {(e["palette"], e["lens"]) for e in fresh}
    kept = {e["fixture"]: e for e in stored
            if (e["palette"], e["lens"]) in same}
    kept.update({e["fixture"]: e for e in fresh})
    order = [f.name for f in FIXTURES]
    return sorted(kept.values(), key=lambda e: order.index(e["fixture"]))


def _write_index(audit_root: Path) -> Path:
    """Rebuild the local landing page from every flavour swept so far."""
    entries: list[dict] = []
    for summary in sorted(audit_root.glob("*/summary.json")):
        entries.extend(json.loads(summary.read_text()))
    index = audit_root / "index.html"
    index.write_text(render_index(entries), encoding="utf-8")
    return index
