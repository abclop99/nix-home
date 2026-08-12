# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a **Home Manager** (Nix) configuration repository for a NixOS system. It manages user-level packages, dotfiles, and services declaratively as a flake. The system-level NixOS config at `/persist/etc/nixos` is a separate flake and does not import `home.nix`.

## Build & Apply Commands

Fish abbreviations expand automatically; the underlying commands are shown for reference.

```bash
# Apply the home-manager configuration
hm-switch
# → home-manager switch --flake /home/abclop99/.config/home-manager#abclop99 --specialisation (darkman get)

# Check for evaluation errors without applying
hm-build
# → home-manager build --flake /home/abclop99/.config/home-manager#abclop99

# Update flake inputs (nixpkgs, home-manager, catppuccin, NUR, etc.)
nix flake update
```

There are no tests or linters configured for this repository. Use `nil` (Nix LSP) for in-editor diagnostics.

`hm-build` writes a `./result/` symlink to the would-be generation; inspect the rendered output (e.g. `grep grace ./result/home-files/.config/hypr/hyprlock.conf`) before running `hm-switch` to verify config changes. Per-variant outputs land at `./result/specialisation/{light,dark}/home-files/…` — useful when a change is gated on `config.theme.variant`.

Note: `grep`/`grep -c` exits **1** on zero matches, so a chained `hm-build && … && grep -c … ` background command reports task status `failed` even when the build succeeded and `0` was the expected count — trust the printed count, not the exit status (or append `|| true`).

**`hm-switch` auto-targets the current darkman mode** via `--specialisation (darkman get)`. To force a different variant, expand the abbreviation in your prompt and edit `(darkman get)` to `light` or `dark` before running. If `darkman` isn't running, the substitution returns empty and the command fails — drop the `--specialisation` flag and invoke `home-manager switch --flake /home/abclop99/.config/home-manager#abclop99` directly. Query the current mode with `darkman get` (sandbox blocks the dbus call — needs disabling per-call).

## Inputs

All dynamic dependencies are pinned via `flake.nix`:

- `nixpkgs` → `github:NixOS/nixpkgs/nixos-26.05`
- `nixpkgs-unstable` → `github:NixOS/nixpkgs/nixpkgs-unstable` — used in `modules/packages.nix` for the up-to-date `claude-code` package (stable's lags; see the `unstable` group's comment there).
- `home-manager` → `github:nix-community/home-manager/release-26.05` (follows `nixpkgs`).
- `catppuccin` → `github:catppuccin/nix/v26.05` (follows `nixpkgs`). Catppuccin's upstream `flake.nix` otherwise pins its *own* moving channel-tarball nixpkgs, which forced the build-time `whiskers` Rust renderer (a `nativeBuildInput` of every catppuccin port, built from source — no `cache.nixos.org` binary, no upstream cachix) to recompile on flake updates that didn't touch our nixpkgs. `follows` dedups it; whiskers still recompiles once when `nixpkgs` itself is bumped.
- `nur` → `github:nix-community/NUR` — wired via overlay (`overlays.default`), so `pkgs.nur.repos.<author>.<pkg>` works.

`flake.lock` is committed and pins everything. Run `nix flake update` to bump them.

**Release-bump cache gotcha:** when bumping a nixpkgs release ref (e.g. `nixos-26.05`), `nix flake update` may lock to an intermediate branch commit — or reuse a *stale* cached rev — that sits between channel bumps and isn't fully on `cache.nixos.org`, triggering large source rebuilds (e.g. `wine`). Force a fresh resolve with `nix flake update nixpkgs --refresh` and confirm the lock matches the channel rev: `curl -sL https://channels.nixos.org/nixos-XX.YY/git-revision`.

**Auto-upgrade risk:** `services.home-manager.autoUpgrade` runs `nix flake update && home-manager switch --flake .` weekly. This advances **every** input on every run, including `nixpkgs-unstable` which tracks the `nixpkgs-unstable` branch — i.e. a moving branch with no stability guarantee. A bad upstream commit landed during the week will be auto-merged into the next switch with no human review. (The previous `home-manager-unstable`/`master` input — formerly imported to supply the unstable `claude-code` HM module — was the worst of these: it once advanced past a `lib.hm.strings.isPathLike` refactor that stable's lib lacked, breaking eval. It has since been dropped; the unstable `claude-code` package is now installed directly via `home.packages` in `modules/packages.nix` (no HM module at all).) The pre-flake setup had a narrower surface: `nix-channel --update` only refreshed `home-manager` (release branch, stable) and `nixpkgs-unstable`. The new fan-out is the price of locking everything.

**Recovery if a weekly upgrade breaks switch:** `~/.local/state/nix/profiles/home-manager-<N-1>-link/activate` runs the prior generation's activate script directly (no CLI needed). Then `nix flake update --override-input <bad-input> github:…<known-good-rev>` (or temporarily `services.home-manager.autoUpgrade.enable = false;`) until upstream stabilises.

To narrow auto-upgrade in the future: replace `useFlake = true;` with a custom user systemd service that runs `nix flake update nixpkgs home-manager catppuccin nur` (omitting `-unstable` inputs), so unstable inputs only advance when manually requested.

## GitHub API token

`nix flake update` re-fetches every `github:` input via the GitHub API. **Anonymous** requests are capped at **60/hour per IP** — exhausted by repeated `nix flake update` runs within the hour (and/or a shared/CGNAT IP pooling that 60) → `HTTP 403 API rate limit exceeded`. Authenticating raises the cap to **5000/hour**. All inputs are **public** repos, so the token needs **no scopes** — it only lifts the rate limit. This also fixes the unattended weekly auto-upgrade (which runs `nix flake update` under `set -euo pipefail` and otherwise hard-fails the switch when rate-limited).

The token is provided via a **relative optional include** in `home.nix`'s `nix.extraOptions` (`!include github-access-tokens.conf`), which pulls in a hand-created machine-local file:

**Per-machine setup** (once, out of band — keeps the secret out of git and out of the store). Create a **classic** PAT with **no scopes** and **"No expiration"** (Settings → Developer settings → Tokens (classic) → check nothing). No-expiry matters: an expired token 401s with **no anonymous fallback** and silently fails the headless weekly auto-upgrade until rotated — so avoid fine-grained/expiring tokens here even though they'd otherwise work. Then, in fish (keeps the token out of shell/Atuin history — this repo syncs Atuin, which records full command lines):
```fish
umask 077                                            # new files this session → 0600
read -s tok                                          # paste the PAT (hidden, not in history)
printf 'access-tokens = github.com=%s\n' "$tok" > ~/.config/nix/github-access-tokens.conf
chmod 600 ~/.config/nix/github-access-tokens.conf    # unconditional 0600 (in case it pre-existed)
set -e tok
```
The file is a plain 0600 nix.conf fragment beside the HM-managed `~/.config/nix/nix.conf` symlink; nothing else is needed in-repo. Rotate/revoke via GitHub if it ever leaks (a no-scope PAT grants no access, only rate-limit budget under your identity). Note `nix config show access-tokens` prints it in plaintext — don't paste that output into bug reports.

## Architecture

- **`flake.nix`** — Flake entry point. Declares inputs (see "Inputs" above), constructs `pkgs` with NUR overlay + `allowUnfree`, exposes `homeConfigurations.abclop99` with `extraSpecialArgs = { inherit inputs; }` so every module can take `inputs`.
- **`home.nix`** — Main HM module. Takes `{ pkgs, inputs, ... }`. Imports all sub-modules, declares core identity (username, XDG, SSH, fontconfig), sets `programs.home-manager.path = inputs.home-manager` so the CLI's `<home-manager/...>` lookups resolve to the flake input.
- **`modules/`** — Split by concern. Modules that need `inputs` take it explicitly (`packages.nix`); others stick with `{ pkgs, ... }:`:
  - `packages.nix` — All `home.packages` (categorized: fonts, cliTools, apps, gaming, mediaTools, unstable). The `unstable` group holds packages pulled from `inputs.nixpkgs-unstable` (currently just `claude-code`, installed bare — no `programs.claude-code` HM module, since no Claude config is managed through HM; pinned to unstable because stable's lags by weeks). Also enables the HM-managed `programs.zellij`/`zathura`/`mpv` (for Catppuccin theming).
  - `shell.nix` — Fish, Bash, Atuin, fzf, zoxide, Starship, pay-respects. Also defines the `hm-switch` / `hm-build` fish abbreviations.
  - `editor.nix` — Helix configuration.
  - `terminal.nix` — Kitty terminal.
  - `git.nix` — Git, delta, GitHub CLI, GPG, gitmoji config.
  - `services.nix` — Syncthing, MPD, udiskie, gnome-keyring, Thunderbird, HM auto-upgrade (flake-mode: `useFlake = true; flakeDir = …`).
  - `hyprland.nix` — Hyprland window manager, keybindings, eww bar, hyprlock, hypridle. Imports host-specific extra binds from `private/hyprland.nix` (skip-worktree'd: empty-`extraBinds` placeholder in git, real binds on disk) and appends them to `settings.bind`.
  - `theme.nix` — Catppuccin theme (Latte/Frappe) with darkman auto-switching via HM specialisations; darkman scripts hardcode `--flake /home/abclop99/.config/home-manager#abclop99`; reads coordinates from `./private/location.nix`. Exposes a read-only `config.theme.palette` attrset (e.g. `palette.mauve`, `palette.subtext0`) for theme-conditional logic in other modules; pattern: `let isLight = config.theme.variant == "latte"; in lib.optionalString isLight "…"`.
  - `firefox.nix` / `librewolf.nix` — Browser configurations with extensions and settings (firefox uses `pkgs.nur.repos.rycee.firefox-addons`).
  - `vscode.nix` — VS Code extensions and settings.
  - `starship.nix` — Starship prompt configuration (imported as a value, not a module).
- **`nixpkgs-config.nix`** — Minimal shared nixpkgs config (just `allowUnfree = true;` — NUR is added via overlay at the flake level, not via `packageOverrides`).
- **`files/`** — Static config files managed via `xdg.configFile` or `home.file`:
  - `eww/` — Eww widget bar (yuck/scss) with scripts for workspace/audio/window info.
  - `firefox/` — Custom CSS (tree-style-tab).
  - `fontconfig/` — Font configuration.
  - `swaylock/` — Custom swaylock effect (C source).
- **`private/`** — Five tracked-but-skip-worktree files (`location.nix`, `ssh/config`, `gpg-key-fingerprint`, `rustdesk.nix`, `hyprland.nix`). The committed content is a placeholder; real values live only on disk. See "Private files" below.
- **`hooks/pre-commit`** — Tracked git hook that rejects commits with staged changes to the `private/` files. Activated per-clone via `git config core.hooksPath hooks`.

## Conventions

- Commit messages use **gitmoji** format (emoji prefix, e.g. `✨`, `🔧`, `👽️`) with a scope in parentheses (e.g. `hypr`, `firefox`, `home`, `eww`, `helix`). Scope = module/area name.
- Commits should be atomic (one logical change each). Non-obvious changes should have a reason in the commit body.
- The configuration targets NixOS 26.05 with Home Manager state version 23.11.
- Several 26.05 default-value changes are pinned to their pre-26.05 values (because state version stays 23.11); see [`docs/26.05-pinned-defaults.md`](docs/26.05-pinned-defaults.md) for the inventory and how to adopt each later.
- `inputs.nixpkgs-unstable` is used selectively (e.g., `claude-code.nix`) for packages needing newer versions.
- Nix experimental features `nix-command` and `flakes` are enabled.
- Default editor is Helix (`hx`), default shell is Fish.
- Keyboard layout is **Norman** — hyprland keybindings use `n/i/o/h` instead of `h/j/k/l`.
- Theme is **Catppuccin** — Frappe (dark) / Latte (light), auto-switched by darkman; variant exposed as `theme.variant` in `modules/theme.nix`.

## Private files

`private/{location.nix,ssh/config,gpg-key-fingerprint,rustdesk.nix,hyprland.nix}` are tracked but `--skip-worktree`'d. The committed content is a placeholder; real values live only in the working tree.

**Per-machine setup (after fresh clone):**
1. `git config core.hooksPath hooks` — activates the pre-commit guard.
2. `git update-index --skip-worktree private/location.nix private/ssh/config private/gpg-key-fingerprint private/rustdesk.nix private/hyprland.nix` — tell git to ignore local edits.
3. Populate real content (via `cat > private/foo` or your editor; the Claude `block-private.sh` hook blocks Edit/Write/MultiEdit, so use Bash or an editor outside Claude).

**Updating placeholder structure** (e.g., adding fields): edit the file, `git add private/foo`, `git commit --no-verify` (the hook would otherwise refuse). Then re-apply skip-worktree if necessary and restore real content.

**Adding new private files**: update both the `SKIP_WORKTREE_FILES` array in `hooks/pre-commit` AND run `git update-index --skip-worktree <new-file>` for each. The two sides are independent — the hook blocks accidental disclosure, the index flag makes git ignore local edits.

**Caveats:**
- `git reset --hard`, `git checkout` between branches, and `git stash pop` can silently flip skip-worktree off or overwrite on-disk real content with the placeholder. If `cat private/location.nix` ever shows zeros after a git operation, restore from a backup or re-edit.
- Skip-worktree'd files are sourced from the **working tree** by the flake's `git+file:` fetcher, but nix caches that snapshot under a key of `<HEAD-rev>;d=<hash of git-visible changes>` (`sourcePathToHash` rows in `~/.cache/nix/fetcher-cache-v4.sqlite`). Skip-worktree files are invisible to `git status`, so **they can never invalidate that key** — editing `private/*` alone leaves every later eval serving the cached tree, and `hm-switch` silently keeps applying the old values. Diagnostic tell: the stale value is the *previous real* value, not the committed placeholder — the snapshot did read the worktree, only invalidation is broken. Confirm by comparing the worktree file against `<flake source path>/private/<file>` (get the path from `nix flake metadata`).
- **What busts the cache:** any real content change to a git-visible tracked file (e.g. `nix flake update` rewriting `flake.lock` — verified 2026-08-12), a commit (new rev ⇒ new key namespace), or deleting the cache row. **What does NOT:** `--refresh` (on `nix flake lock` or `nix flake metadata`), `touch`ing the file, or `--option eval-cache false` — all three re-serve the identical stale store path.
- Old snapshots stay cached **forever under their key**, so whenever the git-visible dirty state returns to a previously-seen combination, nix replays that entire old tree — `private/*` content included. E.g. a `git checkout flake.lock` or a stash/pop that lands back on an earlier dirty state restores that snapshot's private values with nothing in the output saying so.

## Module quirks

- `programs.eww.configDir = <derivation>` makes `~/.config/eww` a symlink to a generation-specific store path; eww-server's socket name is hashed from the resolved path, so it changes on every switch and breaks `eww reload`. Use per-file `xdg.configFile."eww/<file>"` entries to keep the directory stable.
- `catppuccin.enable = true` (from catppuccin/nix) auto-enables every per-app submodule and trips assertions against existing `qt.platformTheme = "gtk"` and firefox extension config. Opt in per app: `catppuccin.<name>.enable = true`.
- Eww uses `grass` for SCSS, which errors `unknown @ rule: @charset "UTF-8";` on any non-ASCII source. Keep `files/eww/eww.scss*` pure ASCII.
- `catppuccin.hyprland` (v26.05) themes via an inline-lua value (`require('themes.catppuccin')`) that only renders under `wayland.windowManager.hyprland.configType = "lua"`; under the pinned `"hyprlang"` it emits an invalid `colors { _var { … } }` block (runtime "config option does not exist" errors). Disabled in `theme.nix` — this config references none of its color vars. (Pre-v26.05 it was passive: it just `source=`d a `$base`/`$blue` color-variable file, themed only if you referenced those vars in `col.active_border` / decoration rules.)
- **hyprlang → lua is the eventual direction.** Hyprland 0.55 (26.05) deprecated hyprlang for lua; this config stays on `configType = "hyprlang"` (pinned) for now — it still works, emits no runtime deprecation warnings (only `windowrulev2` did, already migrated), and has no removal date. Migrating is a *large* rewrite, not a flag flip: under `configType = "lua"` the HM module ignores hyprlang-style strings, so every bind/rule must be native lua (`_args` + `mkLuaInline` + `hl.dsp.*`; hy3 dispatchers via `hl.plugin.hy3`). The HM module auto-renders `settings` as lua and `catppuccin.hyprland` re-enables cleanly under lua. **Revisit when:** home-manager announces removal of its hyprlang backend (or it starts warning), or you want `catppuccin.hyprland` theming back.
- `home.pointerCursor` only manages one cursor theme (XCursor). For a separate hyprcursor theme, symlink it manually via `xdg.dataFile."icons/<name>".source` and set `HYPRCURSOR_THEME`/`HYPRCURSOR_SIZE` in Hyprland's env list.
- `kdePackages.breeze-gtk` is the GTK widget theme and ships no cursors despite the name — use `kdePackages.breeze` for actual Breeze XCursor files.
- Hyprlock 0.9.x dropped the `general.grace` config option; setting it just produces a silent config error. The only way to set a grace period now is the `--grace N` CLI flag (e.g. `hyprlock --grace 5`).
- Hyprlock's `CHyprlockAnimationManager` only registers the `linear` bezier; `animation = fadeIn, 1, 10, default` parses without error but warps to the goal instantly. Pin animations to `linear` (e.g. `animation = fadeIn, 1, 10, linear`) for them to actually animate.
- To audit silently-ignored hyprlock config errors (removed/renamed options, bad `rgb()`/`color=` formats, etc.) run `timeout 2 hyprlock -v -c ~/.config/hypr/hyprlock.conf --grace 0 2>file` and grep `file` for `Config error`. The running hyprlock prints them too but you usually never see its stderr.
- Audit `hyprland.conf` for removed/renamed options with `Hyprland --verify-config -c <conf>` (real errors read `config option <…> does not exist`). It does NOT load plugins, so plugin dispatcher binds (`hy3:*`, …) show as false-positive `Invalid dispatcher` errors — ignore those.
- Touchpad **palm rejection** has no home-manager/Hyprland knob — palm detection lives in libinput (system-level). Per-device `settings.device` `sensitivity` only scales the *accelerated* pointer stream, so it does nothing for tap-clicks or raw input (games read unaccelerated deltas via `zwp_relative_pointer`); `enabled` is all-or-nothing (motion + taps + buttons are one libinput device, Synaptics TM3149-002). Real fixes live system-side (NixOS flake `/persist/etc/nixos`): an evdev filter (`evsieve`/interception-tools) to keep the pad's buttons while dropping motion (works in games too), or libinput `AttrPalmPressureThreshold`/`AttrPalmSizeThreshold` quirks to tune rejection while keeping a working pad.
- `programs.home-manager.package` is `readOnly` in HM 26.05 (auto-derived from `pkgs.callPackage`); don't try to override it. Pin the CLI's `<home-manager/...>` lookup via `programs.home-manager.path = "${inputs.home-manager}"` instead — the wrapper's `setHomeManagerNixPath` (~line 106) injects `-I home-manager=$path` for every `nix-instantiate` site, including the un-gated `build-news.nix` reference at ~line 970.
- `pkgs.system` is deprecated → use `pkgs.stdenv.hostPlatform.system`. Watch the `inherit (pkgs) system;` form — a `pkgs.system` grep misses it (it bit `claude-code.nix`).
- NUR must be wired as an overlay (`inputs.nur.overlays.default`, applied in `flake.nix`). The legacy `inputs.nur = { flake = false; }` + `packageOverrides` pattern in `nixpkgs-config.nix` breaks in pure-flake mode because NUR sub-repos (e.g. `rycee/firefox-addons`) reference `<nixpkgs>` internally; the overlay form lets NUR follow its own pinned nixpkgs.
- `modules/shell.nix` overrides several `fish_color_*` and `fish_pager_color_*` slots on Latte via `interactiveShellInit` because Catppuccin Latte's upstream values (flamingo / pink / yellow / overlay0) sit at 2.3-2.6:1 against `#eff1f5` — well under WCAG AA (4.5:1). Named bindings `dark{Flamingo,Pink,Yellow,Gray}` live in the file-top `let` block; pink and yellow clear AA, flamingo and the gray sit ≈0.1-0.3 below. Frappe is untouched.
- `pkgs.modrinth-app` is wrapped with `jdk8/17/21/25` on its internal PATH (overridable `jdks` arg); these bundled JDKs are detected and fully runnable — they launch both Java *and* the actual game (LWJGL/GL/audio libs resolve), so **`nix-ld` is NOT required** (investigated and confirmed unnecessary on this host). Two traps: **(1)** In Settings → Java installations use **"Detect"**, never **"Install recommended"** — the latter downloads a generic Zulu JRE to `~/.local/share/ModrinthApp/meta/java_versions/` that can't run on stock NixOS (only `stub-ld`, no `programs.nix-ld`): it hangs at "Installing…" and logs `Could not check Java version at path …/zulu…/bin/java`, leaving dead `zulu*` dirs. "Detect" finds the bundled `/nix/store/…-openjdk-XX/lib/openjdk/bin/java` (confirm in `~/.local/share/ModrinthApp/launcher_logs/*.log`). Nothing auto-persists — you must Detect *and select* a result, else instances default to the broken download. **(2)** Modrinth's backend (`check_java_at_filepath`) `canonicalize()`s the selected java and stores the resolved `/nix/store/…/bin/java` realpath in SQLite; it re-canonicalizes each launch but only validates that stored path, so symlinks (`~/.nix-profile/bin/java`) don't help. That path goes stale only after a `nix-collect-garbage` following a JDK store-path bump — launch then fails; no auto-heal, one-click fix is to re-**Detect** (not "Install recommended"). To eliminate the staleness entirely the escalation is `programs.nix-ld.enable = true;` (in `/persist/etc/nixos`) + Modrinth's own managed Zulu (Java then lives under `~/.local/share`, never GC'd) — not worth it while re-Detect suffices. The package is `unfree` (`unfreeRedistributable`), already covered by `allowUnfree`.
- The nix `access-tokens` PAT (see "GitHub API token") is deliberately **not** HM-managed. It must stay in the hand-created `~/.config/nix/github-access-tokens.conf` and be pulled via the **relative `!include github-access-tokens.conf`** in `home.nix`'s `nix.extraOptions`. Never move it into `nix.settings.access-tokens` or write the file via `home.file`/`xdg.configFile` — that serializes the token into the world-readable `/nix/store` (same reason it's not a `private/` file — those are snapshotted into the store by the `git+file:` fetcher). Two load-bearing details: keep the include **relative** (nix resolves it against the config file's own dir `~/.config/nix/`, *not* the store-symlink target, because it doesn't canonicalize the symlink), and keep the **bang** — HM's nix.conf derivation runs a build-time `checkPhase` (`nix config show`) while the token file is absent, and plain `include` (non-optional) fails that check, breaking `hm-build`/`hm-switch`.
- **RustDesk (`modules/rustdesk.nix`) runs `rustdesk --server` (headless), not the bare GUI.** The plain GUI *is* a window: it opens **maximized**, and because it's the systemd user service, every `home-manager switch` (darkman sun-transitions ×2/day, manual `hm-switch`, auto-upgrade) makes `sd-switch` (re)start it — you close the intrusive window → the unit goes *stopped* → the next switch *restarts* it → a fresh window (extra instances even accumulate alongside a manually-opened GUI). `--server` runs with **no window** (nothing to close, so the unit stays *running + unchanged* → `sd-switch` leaves it untouched across switches) **and** auto-spawns the tray. On Linux the systray icon is a **separate `rustdesk --tray` process** that the GUI only launches when a standalone `--server` process exists (`core_main.rs` `check_process("--server")`); the plain GUI runs its server in an in-process *thread*, so there's no `--server` process ⇒ no tray. One `--server` unit yields both server + tray. **Red herring ruled out:** the missing tray is *not* caused by libayatana-appindicator being off `LD_LIBRARY_PATH` — nixpkgs `substituteInPlace`s the **absolute** store path of the lib into `librustdesk.so` (`pkgs/by-name/ru/rustdesk-flutter/package.nix:165-166`), so the `dlopen` succeeds by abspath regardless (a lib-path wrap would be a no-op; verified with `grep -ao`, since a `grep` *without* `-a` false-negatives on the NUL-laden `.so`). `--server` blocks in the foreground → `Type=simple`; its repeated `failed to connect to ipc_service` log lines are **non-fatal** (that IPC is the absent root `rustdesk --service`, needed only for privileged input injection — this box is view-only; the working GUI logs the same misses). Open the GUI on demand with `rustdesk` (still on PATH via `packages.nix`) or the tray's "Open" item. **Reachability is a separate concern:** unattended access needs the custom rendezvous server's hostname to actually **resolve** from this machine — a `home` DNS problem blocked it (the GUI logged 408× `failed to lookup address information`, and no remote connection had ever succeeded). Wayland screen capture goes through xdg-desktop-portal (view-only, no `/dev/uinput`), pre-authorized once via `~/.config/hypr/xdph.conf` `screencopy { allow_token_by_default = true }` — identical for GUI and `--server`.

## Claude Code

- A `PreToolUse` hook (`.claude/hooks/block-private.sh`) blocks `Edit`/`Write`/`MultiEdit` on paths matching `*/private/*` — for `private/` modifications use Bash (e.g., `cat > private/location.nix`).
- Project sandbox is enabled (`.claude/settings.local.json`); commands that need unix sockets or `/dev/tty` (`hm-switch`, `hm-build`, signed `git commit`, writing `.git/config`) need the sandbox disabled per-call.
- The sandbox masks blocked paths with `/dev/null` character devices (mode `crw-rw-rw-`, owner `nobody`) — they appear as untracked entries in `git status` for `.gitconfig`, `.gitmodules`, `.bash_profile`, etc. **Never use `git add .` / `git add -A`**; use selective `git add <path>`.
- `.claude/{settings.json,skills,commands,agents}` are bind-mounted read-only inside any Claude session — to add/modify them, stage in `$TMPDIR` and `cp` from a regular shell.
- `jq` is not installed; use `python3` for JSON parsing in hooks/scripts.
