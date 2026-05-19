# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a **Home Manager** (Nix) configuration repository for a NixOS system. It manages user-level packages, dotfiles, and services declaratively as a flake. The system-level NixOS config at `/persist/etc/nixos` is a separate flake and does not import `home.nix`.

## Build & Apply Commands

Fish abbreviations expand automatically; the underlying commands are shown for reference.

```bash
# Apply the home-manager configuration
hm-switch
# → home-manager switch --flake /home/abclop99/.config/home-manager#abclop99

# Check for evaluation errors without applying
hm-build
# → home-manager build --flake /home/abclop99/.config/home-manager#abclop99

# Update flake inputs (nixpkgs, home-manager, catppuccin, NUR, etc.)
nix flake update
```

There are no tests or linters configured for this repository. Use `nil` (Nix LSP) for in-editor diagnostics.

`hm-build` writes a `./result/` symlink to the would-be generation; inspect the rendered output (e.g. `grep grace ./result/home-files/.config/hypr/hyprlock.conf`) before running `hm-switch` to verify config changes.

## Inputs

All dynamic dependencies are pinned via `flake.nix`:

- `nixpkgs` → `github:NixOS/nixpkgs/nixos-25.11`
- `nixpkgs-unstable` → `github:NixOS/nixpkgs/nixpkgs-unstable` — used in `modules/claude-code.nix` for newer packages.
- `home-manager` → `github:nix-community/home-manager/release-25.11` (follows `nixpkgs`).
- `home-manager-unstable` → `github:nix-community/home-manager/master` (follows `nixpkgs-unstable`) — used in `modules/claude-code.nix` for the unstable `claude-code` HM module.
- `catppuccin` → `github:catppuccin/nix/v25.11`.
- `nur` → `github:nix-community/NUR` — wired via overlay (`overlays.default`), so `pkgs.nur.repos.<author>.<pkg>` works.

`flake.lock` is committed and pins everything. Run `nix flake update` to bump them.

**Auto-upgrade risk:** `services.home-manager.autoUpgrade` runs `nix flake update && home-manager switch --flake .` weekly. This advances **every** input on every run, including `nixpkgs-unstable` and `home-manager-unstable` which track `nixpkgs-unstable` and `master` respectively — i.e. moving branches with no stability guarantee. A bad upstream commit landed during the week will be auto-merged into the next switch with no human review. The pre-flake setup had a narrower surface: `nix-channel --update` only refreshed `home-manager` (release branch, stable) and `nixpkgs-unstable`. The new fan-out is the price of locking everything.

**Recovery if a weekly upgrade breaks switch:** `~/.local/state/nix/profiles/home-manager-<N-1>-link/activate` runs the prior generation's activate script directly (no CLI needed). Then `nix flake update --override-input <bad-input> github:…<known-good-rev>` (or temporarily `services.home-manager.autoUpgrade.enable = false;`) until upstream stabilises.

To narrow auto-upgrade in the future: replace `useFlake = true;` with a custom user systemd service that runs `nix flake update nixpkgs home-manager catppuccin nur` (omitting `-unstable` inputs), so unstable inputs only advance when manually requested.

## Architecture

- **`flake.nix`** — Flake entry point. Declares inputs (see "Inputs" above), constructs `pkgs` with NUR overlay + `allowUnfree`, exposes `homeConfigurations.abclop99` with `extraSpecialArgs = { inherit inputs; }` so every module can take `inputs`.
- **`home.nix`** — Main HM module. Takes `{ pkgs, inputs, ... }`. Imports all sub-modules, declares core identity (username, XDG, SSH, fontconfig), sets `programs.home-manager.path = inputs.home-manager` so the CLI's `<home-manager/...>` lookups resolve to the flake input.
- **`modules/`** — Split by concern. Modules that need `inputs` take it explicitly (`claude-code.nix`); others stick with `{ pkgs, ... }:`:
  - `packages.nix` — All `home.packages` (categorized: fonts, cliTools, apps, gaming, mediaTools).
  - `shell.nix` — Fish, Bash, Atuin, fzf, zoxide, Starship, pay-respects. Also defines the `hm-switch` / `hm-build` fish abbreviations.
  - `editor.nix` — Helix configuration.
  - `claude-code.nix` — Claude Code configuration (uses `inputs.home-manager-unstable`'s module + `inputs.nixpkgs-unstable`'s package).
  - `terminal.nix` — Kitty terminal.
  - `git.nix` — Git, delta, GitHub CLI, GPG, gitmoji config.
  - `services.nix` — Syncthing, MPD, udiskie, gnome-keyring, Thunderbird, HM auto-upgrade (flake-mode: `useFlake = true; flakeDir = …`).
  - `hyprland.nix` — Hyprland window manager, keybindings, eww bar, hyprlock, hypridle.
  - `theme.nix` — Catppuccin theme (Latte/Frappe) with darkman auto-switching via HM specialisations; darkman scripts hardcode `--flake /home/abclop99/.config/home-manager#abclop99`; reads coordinates from `./private/location.nix`.
  - `firefox.nix` / `librewolf.nix` — Browser configurations with extensions and settings (firefox uses `pkgs.nur.repos.rycee.firefox-addons`).
  - `vscode.nix` — VS Code extensions and settings.
  - `starship.nix` — Starship prompt configuration (imported as a value, not a module).
- **`nixpkgs-config.nix`** — Minimal shared nixpkgs config (just `allowUnfree = true;` — NUR is added via overlay at the flake level, not via `packageOverrides`).
- **`files/`** — Static config files managed via `xdg.configFile` or `home.file`:
  - `eww/` — Eww widget bar (yuck/scss) with scripts for workspace/audio/window info.
  - `firefox/` — Custom CSS (tree-style-tab).
  - `fontconfig/` — Font configuration.
  - `swaylock/` — Custom swaylock effect (C source).
- **`private/`** — Three tracked-but-skip-worktree files (`location.nix`, `ssh/config`, `gpg-key-fingerprint`). The committed content is a placeholder; real values live only on disk. See "Private files" below.
- **`hooks/pre-commit`** — Tracked git hook that rejects commits with staged changes to the three `private/` files. Activated per-clone via `git config core.hooksPath hooks`.

## Conventions

- Commit messages use **gitmoji** format (emoji prefix, e.g. `✨`, `🔧`, `👽️`) with a scope in parentheses (e.g. `hypr`, `firefox`, `home`, `eww`, `helix`). Scope = module/area name.
- Commits should be atomic (one logical change each). Non-obvious changes should have a reason in the commit body.
- The configuration targets NixOS 25.11 with Home Manager state version 23.11.
- `inputs.nixpkgs-unstable` is used selectively (e.g., `claude-code.nix`) for packages needing newer versions.
- Nix experimental features `nix-command` and `flakes` are enabled.
- Default editor is Helix (`hx`), default shell is Fish.
- Keyboard layout is **Norman** — hyprland keybindings use `n/i/o/h` instead of `h/j/k/l`.
- Theme is **Catppuccin** — Frappe (dark) / Latte (light), auto-switched by darkman; variant exposed as `theme.variant` in `modules/theme.nix`.

## Private files

`private/{location.nix,ssh/config,gpg-key-fingerprint}` are tracked but `--skip-worktree`'d. The committed content is a placeholder; real values live only in the working tree.

**Per-machine setup (after fresh clone):**
1. `git config core.hooksPath hooks` — activates the pre-commit guard.
2. `git update-index --skip-worktree private/location.nix private/ssh/config private/gpg-key-fingerprint` — tell git to ignore local edits.
3. Populate real content (via `cat > private/foo` or your editor; the Claude `block-private.sh` hook blocks Edit/Write/MultiEdit, so use Bash or an editor outside Claude).

**Updating placeholder structure** (e.g., adding fields): edit the file, `git add private/foo`, `git commit --no-verify` (the hook would otherwise refuse). Then re-apply skip-worktree if necessary and restore real content.

**Adding new private files**: update both the `SKIP_WORKTREE_FILES` array in `hooks/pre-commit` AND run `git update-index --skip-worktree <new-file>` for each. The two sides are independent — the hook blocks accidental disclosure, the index flag makes git ignore local edits.

**Caveats:**
- `git reset --hard`, `git checkout` between branches, and `git stash pop` can silently flip skip-worktree off or overwrite on-disk real content with the placeholder. If `cat private/location.nix` ever shows zeros after a git operation, restore from a backup or re-edit.
- Skip-worktree'd files are sourced from the **working tree** by the flake's `git+file:` fetcher, but the source store path is keyed on the git `rev`. After editing real content on disk without committing, the next `hm-switch` may reuse a cached source path. Force re-snapshot via `nix flake lock --refresh` or a no-op commit.

## Module quirks

- `programs.eww.configDir = <derivation>` makes `~/.config/eww` a symlink to a generation-specific store path; eww-server's socket name is hashed from the resolved path, so it changes on every switch and breaks `eww reload`. Use per-file `xdg.configFile."eww/<file>"` entries to keep the directory stable.
- `catppuccin.enable = true` (from catppuccin/nix) auto-enables every per-app submodule and trips assertions against existing `qt.platformTheme = "gtk"` and firefox extension config. Opt in per app: `catppuccin.<name>.enable = true`.
- Eww uses `grass` for SCSS, which errors `unknown @ rule: @charset "UTF-8";` on any non-ASCII source. Keep `files/eww/eww.scss*` pure ASCII.
- `catppuccin.hyprland.enable` is passive: it only `source=`s a color-variable file (`$base`, `$blue`, …) into hyprland.conf — nothing themes until you reference those vars in `col.active_border` / decoration rules.
- `home.pointerCursor` only manages one cursor theme (XCursor). For a separate hyprcursor theme, symlink it manually via `xdg.dataFile."icons/<name>".source` and set `HYPRCURSOR_THEME`/`HYPRCURSOR_SIZE` in Hyprland's env list.
- `kdePackages.breeze-gtk` is the GTK widget theme and ships no cursors despite the name — use `kdePackages.breeze` for actual Breeze XCursor files.
- Hyprlock 0.9.x dropped the `general.grace` config option; setting it just produces a silent config error. The only way to set a grace period now is the `--grace N` CLI flag (e.g. `hyprlock --grace 5`).
- Hyprlock's `CHyprlockAnimationManager` only registers the `linear` bezier; `animation = fadeIn, 1, 10, default` parses without error but warps to the goal instantly. Pin animations to `linear` (e.g. `animation = fadeIn, 1, 10, linear`) for them to actually animate.
- To audit silently-ignored hyprlock config errors (removed/renamed options, bad `rgb()`/`color=` formats, etc.) run `timeout 2 hyprlock -v -c ~/.config/hypr/hyprlock.conf --grace 0 2>file` and grep `file` for `Config error`. The running hyprlock prints them too but you usually never see its stderr.

## Claude Code

- A `PreToolUse` hook (`.claude/hooks/block-private.sh`) blocks `Edit`/`Write`/`MultiEdit` on paths matching `*/private/*` — for `private/` modifications use Bash (e.g., `cat > private/location.nix`).
- Project sandbox is enabled (`.claude/settings.local.json`); commands that need unix sockets or `/dev/tty` (`hm-switch`, `hm-build`, signed `git commit`, writing `.git/config`) need the sandbox disabled per-call.
- `.claude/{settings.json,skills,commands,agents}` are bind-mounted read-only inside any Claude session — to add/modify them, stage in `$TMPDIR` and `cp` from a regular shell.
- `jq` is not installed; use `python3` for JSON parsing in hooks/scripts.
