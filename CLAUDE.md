# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a **Home Manager** (Nix) configuration repository for a NixOS system. It manages user-level packages, dotfiles, and services declaratively using the Nix module system. There is no flake.nix — this configuration is consumed by the system-level NixOS configuration (likely at `/persist/etc/nixos`).

## Build & Apply Commands

```bash
# Apply the home-manager configuration
home-manager switch

# Check for evaluation errors without applying
home-manager build

# Apply with verbose output for debugging
home-manager switch --show-trace
```

There are no tests or linters configured for this repository. Use `nil` (Nix LSP) for in-editor diagnostics.

## Architecture

- **`home.nix`** — Main entry point. Imports all modules, declares core identity (username, XDG, SSH, fontconfig, nixpkgs config).
- **`modules/`** — Split by concern, each following the `{ pkgs, ... }: { config = { ... }; }` pattern:
  - `packages.nix` — All `home.packages` (categorized: fonts, cliTools, apps, gaming, mediaTools).
  - `shell.nix` — Fish, Bash, Atuin, fzf, zoxide, Starship, pay-respects.
  - `editor.nix` — Helix configuration.
  - `claude-code.nix` — Claude Code configuration (uses unstable HM module + nixpkgs-unstable package).
  - `terminal.nix` — Kitty terminal.
  - `git.nix` — Git, delta, GitHub CLI, GPG, gitmoji config.
  - `services.nix` — Syncthing, MPD, udiskie, gnome-keyring, Thunderbird, HM auto-upgrade.
  - `hyprland.nix` — Hyprland window manager, keybindings, eww bar, hyprlock, hypridle.
  - `theme.nix` — Catppuccin theme (Latte/Frappe) with darkman auto-switching via HM specialisations; reads coordinates from `private/location.nix`.
  - `firefox.nix` / `librewolf.nix` — Browser configurations with extensions and settings.
  - `vscode.nix` — VS Code extensions and settings.
  - `starship.nix` — Starship prompt configuration (imported as a value, not a module).
- **`nixpkgs-config.nix`** — Shared nixpkgs config (allowUnfree, etc.), used both by HM and standalone nix commands.
- **`files/`** — Static config files managed via `xdg.configFile` or `home.file`:
  - `eww/` — Eww widget bar (yuck/scss) with scripts for workspace/audio/window info.
  - `firefox/` — Custom CSS (tree-style-tab).
  - `fontconfig/` — Font configuration.
  - `swaylock/` — Custom swaylock effect (C source).
- **`private/`** — Optional directory (not committed) for sensitive config: SSH host configs (`private/ssh/config`) and GPG key fingerprint (`private/gpg-key-fingerprint`). Code checks `builtins.pathExists` before using these.

## Conventions

- Commit messages use **gitmoji** format (emoji prefix, e.g. `✨`, `🔧`, `👽️`) with a scope in parentheses (e.g. `hypr`, `firefox`, `home`, `eww`, `helix`). Scope = module/area name.
- Commits should be atomic (one logical change each). Non-obvious changes should have a reason in the commit body.
- The configuration targets NixOS 25.11 (stable channel) with Home Manager state version 23.11.
- `nixpkgs-unstable` channel is used selectively (e.g., `claude-code.nix`) for packages needing newer versions.
- Nix experimental features `nix-command` and `flakes` are enabled.
- Default editor is Helix (`hx`), default shell is Fish.
- Keyboard layout is **Norman** — hyprland keybindings use `n/i/o/h` instead of `h/j/k/l`.
- Theme is **Catppuccin** — Frappe (dark) / Latte (light), auto-switched by darkman; variant exposed as `theme.variant` in `modules/theme.nix`.

## Module quirks

- `programs.eww.configDir = <derivation>` makes `~/.config/eww` a symlink to a generation-specific store path; eww-server's socket name is hashed from the resolved path, so it changes on every switch and breaks `eww reload`. Use per-file `xdg.configFile."eww/<file>"` entries to keep the directory stable.
- `catppuccin.enable = true` (from catppuccin/nix) auto-enables every per-app submodule and trips assertions against existing `qt.platformTheme = "gtk"` and firefox extension config. Opt in per app: `catppuccin.<name>.enable = true`.
- Eww uses `grass` for SCSS, which errors `unknown @ rule: @charset "UTF-8";` on any non-ASCII source. Keep `files/eww/eww.scss*` pure ASCII.
- `catppuccin.hyprland.enable` is passive: it only `source=`s a color-variable file (`$base`, `$blue`, …) into hyprland.conf — nothing themes until you reference those vars in `col.active_border` / decoration rules.

## Claude Code

- A `PreToolUse` hook (`.claude/hooks/block-private.sh`) blocks `Edit`/`Write`/`MultiEdit` on paths matching `*/private/*` — don't attempt edits there (gitignored SSH host config + GPG fingerprint).
- Project sandbox is enabled (`.claude/settings.local.json`); commands that need unix sockets or `/dev/tty` (`home-manager switch`, signed `git commit`) need the sandbox disabled per-call.
- `.claude/{settings.json,skills,commands,agents}` are bind-mounted read-only inside any Claude session — to add/modify them, stage in `$TMPDIR` and `cp` from a regular shell.
- `jq` is not installed; use `python3` for JSON parsing in hooks/scripts.
