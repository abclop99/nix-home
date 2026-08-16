# Contrast audit harness — design

Date: 2026-08-12

## Context

Several things in this configuration's color themes are hard to read. A patch
already exists for ten fish color slots under Latte (`modules/shell.nix`), added
ad hoc after the problem was noticed by eye. The open question was whether that
was three unlucky slots or a symptom of something structural.

Measuring the palettes in `modules/theme.nix` against WCAG 2.1 answers it:

| variant | slots below AA (4.5:1) | slots below 3:1 |
|---|---|---|
| Latte (on `#eff1f5`) | 16 / 20 | 11 / 20 |
| Frappe (on `#303446`) | 2 / 20 | 1 / 20 |

Frappe is healthy — only `overlay0` (2.87:1, used for comments) genuinely fails,
with `overlay1` (3.65:1) borderline. Latte is not: `overlay0` 2.30, `yellow`
2.31, `pink` 2.34, `rosewater` 2.34, `sky` 2.47, `peach` and `flamingo` 2.64,
`sapphire` 2.78, `lavender` 2.81, `overlay1` 2.83, `green` 2.96. Only `text`,
`subtext1`, `red` and `mauve` clear AA. Catppuccin Latte's accents are close to
its dark-mode pastels and were not designed to carry text on a near-white base.

That makes "patch the slots" and "replace the theme" both defensible, and the
choice is aesthetic as much as numerical — the fix has to *look good*, and
darkening eleven accents risks turning a soft pastel theme muddy. Numbers alone
cannot settle it. This spec covers building the instrument that can: a harness
that captures what programs actually render and turns it into both an image to
judge and a measurement to check.

## Goals

- Capture real terminal output from a representative set of programs, under any
  Catppuccin flavor, without switching the live theme.
- Render each capture to a PNG that faithfully reproduces what kitty shows.
- Report every distinct foreground/background pair with its contrast ratio, how
  many cells use it, and a sample of the affected text.
- Record, for each finding, whether fixing it needs a per-application theme
  override or only a palette change — so the cheapest adequate fix can be
  chosen, and applications that already read acceptably are left alone.
- Make the sweep repeatable, so a candidate fix can be measured the same way.

## Non-goals

- Choosing or implementing the fix. That is the decision this harness informs,
  taken separately once its output exists.
- The eww bar and GTK theming. They need a different capture path; eww's SCSS
  colors can be checked numerically without this harness if wanted later.
- A general-purpose terminal screenshot tool. Fidelity matters only insofar as
  it supports a color judgment.

## Architecture

Four units with narrow interfaces, each usable and testable alone.

| unit | responsibility | interface |
|---|---|---|
| `drive` | run a command in a pty at a fixed size with `XDG_CONFIG_HOME` pointed at the chosen variant's rendered configs, optionally send scripted keystrokes with delays, capture raw bytes until output goes quiet or a timeout expires | `(cmd, keys, size, env) -> bytes` |
| `emulate` | feed bytes through `pyte` to obtain a cell grid carrying char, fg, bg and the bold/reverse attributes | `bytes -> Cell[][]` |
| `resolve` | turn each cell's symbolic color into concrete RGB under a supplied palette | `(Cell[][], palette) -> RGBCell[][]` |
| `render` | draw the grid to PNG, and reduce it to a contrast report | `RGBCell[][] -> (png, report)` |

`drive` is the only unit that touches processes; `resolve` is the only unit that
knows about Catppuccin; `render` is the only unit that knows about fonts. A
change to the fixture list touches none of them.

### Palette resolution

This is the correctness-critical unit. It reads the same
`Catppuccin-<Flavor>.conf` that `kitty.conf` includes, rather than a hand-copied
table, so measurements reflect what the terminal actually displays. All four
flavor confs ship in one `kitty-themes` store path, so selecting a flavor is a
filename change.

Resolution rules:

- `default` foreground/background resolve to the conf's `foreground` /
  `background`.
- Indices 0–15 resolve to `color0`..`color15`.
- 256-color cube and grayscale ramp indices resolve by the standard formula.
- Truecolor values pass through unchanged.
- The `reverse` attribute swaps foreground and background before measurement.
- `bold` does not brighten: kitty leaves bold color alone by default.

### Rendering

Pillow, drawing one rectangle per cell background and one glyph per cell
foreground. The font is `nerd-fonts.fira-code` — already installed, and patched
with the powerline and icon glyphs that eza, starship and zellij emit, so a
single TTF covers every fixture with no font-fallback logic.

### Reporting

Per capture: every distinct `(fg, bg)` pair with its WCAG 2.1 ratio, the cell
count, and a sample of the text using it, sorted worst first. Per sweep: a
summary table of each fixture's worst pair and its count of cells below 4.5:1
and below 3:1.

The working bar is that text meant to be read reaches roughly 4.5:1 and text
that is dim by design reaches roughly 3:1. It is a guide for ranking findings,
not an acceptance gate — the images are what decide.

Every reported pair also carries **how it would have to be fixed**, because the
guiding principle is to add no per-application theme override for an application
that already reads acceptably. Only what measurement proves broken gets touched.

- **Palette-level** — the color came from an ANSI slot (`color0`..`color15`) or
  the default foreground. Correctable once in `programs.kitty.settings`, fixing
  every application that emits ANSI colors at the same time, with no per-app
  config anywhere.
- **Application-level** — the application emitted a truecolor value from its own
  theme file. Correctable only by overriding that application's theme.

`resolve` already knows which case each cell was, so this classification is
recorded rather than inferred later. The value is that it prices the fix before
any is chosen: a finding list that is mostly palette-level argues for repaletting
Latte in one place, while one dominated by application-level findings means the
override burden is real and replacing the theme deserves more weight.

## Fixtures

Declarative entries of `name / command / keys / size`. The first six capture
plain output; the last four need the keystroke driver.

| fixture | what it exercises |
|---|---|
| `fish-syntax` | fish syntax highlighting: quotes, redirection, flags, an invalid command, autosuggestion |
| `starship-dirty` | starship segments in a git repo with staged and unstaged changes |
| `eza-long` | `eza -laa` with icons, color-scale, group and header |
| `bat-nix` | bat syntax highlighting on `modules/theme.nix` |
| `delta-diff` | `git diff` through delta: added, removed and context lines |
| `rg-matches` | ripgrep match highlighting and file/line headers |
| `fzf-preview` | fzf picker with a bat preview and a typed query |
| `atuin-search` | atuin's interactive history TUI with a typed query |
| `helix-nix` | helix on a `.nix` file: statusline, gutter, selection, cursorline, indent guides, diagnostics |
| `zellij-panes` | zellij tab bar, pane borders and status bar with a split |

Default size 100x30; 120x36 for `helix-nix` and `zellij-panes`.

## Sweep matrix

A capture has two independent inputs, and conflating them would make the results
wrong:

1. **The ANSI palette** handed to `resolve`, which decides how indexed colors
   are rendered.
2. **The application configs** the driven program reads, which decide the
   truecolor values it emits. helix, bat, delta, atuin and zellij all carry a
   per-variant theme of their own; swapping the kitty palette does not touch
   them.

> **Superseded in part.** This describes the configuration as it stood when the
> harness was designed. What the harness then measured led to bat, fish and fzf
> moving onto ANSI-indexed colour, and delta onto its own defaults plus a
> per-variant syntax theme — so of the programs named above, only helix, atuin
> and zellij still carry a truecolor theme, and only helix is exercised by a
> fixture. See the ANSI notes in `CLAUDE.md` and `modules/theme.nix` for the
> reasoning and the measurements behind it. The design below is left as written;
> it is a record of the instrument, not of the configuration it measures.

Getting only the first right would render a Latte terminal running Frappe-themed
applications — a picture of nothing real. So `drive` sets `XDG_CONFIG_HOME` to
the matching rendered specialisation,
`./result/specialisation/{light,dark}/home-files/.config`, which `hm-build`
already produces. The live theme is never switched and the running session is
unaffected.

That gives two fully faithful variants:

- **Latte** — `specialisation/light` configs, `Catppuccin-Latte.conf` palette.
- **Frappe** — `specialisation/dark` configs, `Catppuccin-Frappe.conf` palette.

**Macchiato and Mocha have no built specialisation**, so they can only be
rendered at the ANSI layer — accurate for fish, eza, ripgrep and git, misleading
for helix, bat, delta, atuin and zellij. Rendering them faithfully needs a
rendered config tree, obtained with a temporary uncommitted edit to the
`theme.variant` enum and specialisation list in `modules/theme.nix`, then
`hm-build`, capture, and revert. Nothing is committed and no permanent
specialisation is added. Editing a git-visible tracked file invalidates nix's
fetcher cache normally, so the build reflects the edit.

This is optional and deferred: the sweep runs Latte and Frappe first, and the
extra flavors are rendered only if the first results make the family comparison
worth the rebuild.

The existing fish patch in `modules/shell.nix` is not a palette difference — it
is `set -g fish_color_*` inside fish's own config, so it is already present in
the Latte capture. Seeing unpatched Latte means running the `fish-syntax` fixture
once with those variables unset, which is a fixture variant rather than a sixth
column.

### Config resolution — verified 2026-08-13

`XDG_CONFIG_HOME` alone is not sufficient. Probed each program by overriding it
to the light specialisation and asking the program which config it resolved:

| program | honors `XDG_CONFIG_HOME` | harness must |
|---|---|---|
| fish | yes | nothing |
| helix | yes | nothing |
| atuin | yes | nothing |
| bat | yes (only since `programs.bat.enable`) | nothing |
| git → delta | yes, via git's own XDG fallback | nothing |
| **zellij** | **no** — resolves `~/.config/zellij` | set `ZELLIJ_CONFIG_DIR` |
| **fzf** | no config file at all | inject `FZF_DEFAULT_OPTS` |
| **starship** | `STARSHIP_CONFIG` wins | override it |
| eza, ripgrep | no config file; env-var only | nothing |

Three further findings:

- **The variant tree is read-only** — mode `0555`, owned by uid 0, since it is a
  store path. fish writes `fish_variables` into its config dir, and atuin and
  zellij touch theirs, so `drive` must copy the tree to a writable temp
  directory per run. Otherwise write failures land in the captured frame and
  become fake findings.
- **bat needs its theme cache built per variant.** Home Manager writes
  `bat/themes/*.tmTheme`, but bat cannot use a `.tmTheme` until
  `bat cache --build` compiles it into `themes.bin`. HM runs that at
  *activation*, so a specialisation tree taken straight from `hm-build` has the
  theme file but no cache, and bat silently renders its built-in default —
  **identically under both variants**, which looks exactly like a failed config
  override. Verified 2026-08-13: with `XDG_CACHE_HOME` pointed at a temp dir and
  `bat cache --build` run per variant, output diverges correctly (light emits
  Latte `overlay1` `#8c8fa1`, dark emits Frappe `overlay1` `#838ba7`).

  So `drive` must set `XDG_CACHE_HOME` to a per-variant temp directory and run
  `bat cache --build` once per variant before capturing. Any other program that
  compiles assets at activation needs the same treatment; bat is the one found
  so far. This is also why bat must not be used as the cross-variant canary —
  it can fail that check for a reason unrelated to config resolution.
- **`FZF_DEFAULT_OPTS` and `STARSHIP_CONFIG` live in
  `home-path/etc/profile.d/hm-session-vars.fish`, not under `home-files`.** The
  fzf value is genuinely per-variant (Latte `bg:#eff1f5 … spinner:#dc8a78`
  versus Frappe `bg:#303446 … spinner:#f2d5cf`), so it must be read from the
  variant's own file rather than inherited from the live session. Incidentally
  that Latte spinner is rosewater at 2.34:1 — a finding the sweep should
  reproduce.
- **`STARSHIP_CONFIG` is pinned to the live path in both variants, but this is
  harmless**: `starship.toml` is byte-identical across variants and carries
  almost no color, so starship rides the ANSI palette and will be corrected by a
  palette change for free. Override it anyway for correctness, not urgency.
- **That same file re-exports `XDG_CONFIG_HOME` to the live path**, so any
  fixture that goes through fish leaks the live config dir to its children.
  fish's own colors are unaffected (it resolves `__fish_config_dir` first), but
  anything fish shells out to is not.

## Packaging

A `pkgs.writers.writePython3Bin` derivation exposed as a flake app, invoked as
`nix run .#contrast-audit`. Pillow, pyte and the font's store path are baked into
the derivation. Nothing is added to `home.packages`, and no ad-hoc `nix shell` is
needed. PNGs and reports are written to `audit/`, added to `.gitignore` — the
images are large and regenerable, so they do not belong in git.

## Verification

The harness is worthless if its output does not match reality, so that is
checked before any measurement is trusted.

An earlier draft proposed rendering `bat-nix` under Frappe and comparing by eye.
Both halves were wrong. `bat` emits only truecolor, so it exercises neither the
ANSI path nor the 256-index sentinel scheme — precisely the correctness-critical
code the check exists to validate. And eye comparison does not reliably catch a
few-percent hue shift, which is the failure mode. So the check uses an
ANSI-emitting fixture and compares color sets numerically.

**Result — 2026-08-13, Latte: passed.** `rg-matches` captured from a real
fullscreen kitty via `grimblast save active`, with `background_opacity 1.0` and
the hyprshade blue-light filter cleared. Every color the harness computed
appears *exactly* in the capture:

| harness computed | pixels in capture |
| --- | --- |
| `#eff1f5` background | 2,053,477 |
| `#4c4f69` default foreground | 2,011 |
| `#d20f39` ANSI red | 1,410 |
| `#ea76cb` ANSI magenta | 623 |
| `#40a02b` ANSI green | 104 |

The comparison is one-directional — extra colors in the capture are expected.
Antialiasing contributes intermediates, and `#dc8a78` (rosewater) is the block
cursor, which the harness does not model.

This validates palette loading through the Catppuccin `include`, ANSI slot
resolution, and default foreground/background resolution.

`bat-nix` was then captured the same way to cover the truecolor path, which is
what bat, delta, helix and atuin all emit. Again every value matched exactly:

| harness computed | token | pixels in capture |
| --- | --- | --- |
| `#eff1f5` | base | 1,999,238 |
| `#40a02b` | green | 4,884 |
| `#8c8fa1` | overlay1 | 4,688 |
| `#7c7f93` | overlay2 | 2,828 |
| `#1e66f5` | blue | 2,031 |
| `#4c4f69` | text | 1,642 |
| `#179299` | teal | 180 |

Those being Latte tokens rather than Monokai Extended also confirms the
`programs.bat.enable` fix reached the live terminal, not just the generated
config.

`#40a02b` appears in both captures — reached through the ANSI green slot by
`rg` and through a truecolor escape by `bat` — and resolves identically either
way, which is the intended behaviour: the sentinel scheme keeps the two
distinguishable for tier classification while agreeing on the value.

Still uncovered: the 256-cube path, dim, and reverse. No fixture emits them.

Two conditions are load-bearing for the reference capture. The window must be
genuinely fullscreen, because Hyprland's `match:fullscreen 0, opacity 0.95`
(`modules/hyprland.nix:289`) composites the entire window surface, glyphs
included. And the blue-light filter must be off — it multiplies every pixel by
roughly (1.000, 0.651, 0.304), which would fail the comparison wholesale.

Each unit is additionally checked on its own: `emulate` against a fixed byte
string with known SGR sequences, `resolve` against hand-computed values for one
color of each kind (default, indexed, 256-cube, truecolor, reversed), and the
ratio function against published WCAG examples.

## Assumptions and risks

### pyte's colour model — verified 2026-08-13 against pyte 0.8.2

Probed directly; all four questions the resolver depends on are settled.

- **Named colours** come through as pyte's own names, and index 3 is `brown`,
  not `yellow`: `black red green brown blue magenta cyan white`. Bright variants
  are `bright` + that name, so index 11 is `brightbrown`.
- **`BG_AIXTERM[105]` is `bfightmagenta`** — a real typo in 0.8.2, fixed only on
  upstream master. It appears **only as a background**; `FG_AIXTERM[95]` is
  correctly `brightmagenta`. Unhandled it falls through to the hex parser and
  aborts the sweep, so `resolve` maps it to index 13 explicitly.
- **256-indexed colours collapse to xterm hex.** `\e[38;5;1m` yields `cd0000`
  and `\e[38;5;7m` yields `e5e5e5` — pyte's own table, not the theme's. This is
  why the sentinel scheme exists: without it, palette slot identity is destroyed
  and a cube colour is indistinguishable from an identical truecolour value.
  `FG_BG_256` is a plain mutable 256-entry list, so replacing it works.
- **SGR 2 (dim) is not represented at all**, but it is recoverable. pyte's
  `TEXT` map has no entry for 2, so out of the box dim text arrives at full
  colour and its contrast is *overstated*. That matters here specifically:
  `kitty.conf` sets `dim_opacity 0.75` because dim text was unreadable on this
  system, so the harness would be blind to a problem this configuration has
  already hit.

  Verified fix, three lines, tested end to end: `Char` is a `NamedTuple` and
  `select_graphic_rendition` maps `TEXT` entries straight onto field names via
  `_replace`, so declaring a `Char` subclass with an extra `dim` field, setting
  `pyte.screens.Char` to it, and adding `TEXT[2] = "+dim"` is sufficient. One
  non-obvious detail: `Screen.reset()` does `self.cursor = Cursor(0, 0)`, and
  `Cursor.__init__`'s default `attrs` was bound to the *original* `Char` at
  class-definition time, so `pyte.screens.Cursor.__init__.__defaults__` must be
  repointed as well or the first SGR raises `TypeError: Got unexpected field
  names: ['dim']`. Bold, truecolour and double-width handling are unaffected.

  Known divergence: real terminals treat SGR 22 as "normal intensity" and clear
  bold *and* dim, but pyte's `TEXT[22]` is `-bold` and a dict cannot map one
  code to two fields. Dim therefore persists until a full SGR 0 reset, which is
  what programs emit in practice. Revisit only if a fixture shows sticky dim.

  `resolve` then blends dim cells toward the background using kitty's own
  semantics: `dim_opacity` is the fraction of the original colour retained, so
  the effective foreground is `mix(bg, fg, dim_opacity)`.
- **Double-width glyphs** leave `''` in the trailing cell. Preserved as-is;
  coercing it to a space would shift every following column.
- **No alternate-screen support** (no private modes 47/1047/1048/1049), so
  full-screen TUIs draw over the primary buffer rather than a cleared one.
- **Interactive fixtures are timing-dependent.** `helix-nix`, `zellij-panes`,
  `fzf-preview` and `atuin-search` need the program to finish drawing before
  capture. Mitigated by reading until output is quiet for a fixed interval rather
  than sleeping a fixed time, with a timeout as a backstop.
- **`zellij-panes` may need an isolated session** so the capture does not attach
  to or disturb a running one. It uses a dedicated session name and is killed
  afterwards.
- **A current `./result` is a prerequisite.** The variant configs come from
  `hm-build` output, so a stale or missing `result` symlink yields captures of an
  old configuration. The harness checks that the specialisation paths exist and
  refuses to run if they do not, rather than silently falling back to the live
  `~/.config`.
- **Some programs ignore `XDG_CONFIG_HOME`.** Any fixture whose program reads a
  hardcoded `~/.config` path would capture live config instead of the variant's.
  Each fixture is confirmed to honor the override when it is first added; those
  that do not get an explicit config flag instead.

## What follows

The sweep produces images and reports; those are reviewed together, and only
then is the direction chosen — repalette Latte in place, replace the light theme,
or move off Catppuccin. Each is a separate piece of work with its own plan.

For reference, the leverage point found while investigating: the rendered
`kitty.conf` places the Catppuccin `include` at line 6 and Home Manager's
`settings` at lines 11–17, and later directives win in kitty. So
`programs.kitty.settings.color1` and friends override the theme, and correcting
the 16 ANSI slots plus `foreground` in one place would reach every app that emits
ANSI colors. Only programs emitting truecolor directly — helix (a full
`themes/catppuccin-latte.toml`, overridable through helix's `inherits`), atuin,
zellij and eww — would need individual treatment. This matters only if
repaletting is the chosen direction.
