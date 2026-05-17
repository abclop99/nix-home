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

- **`home.nix`** — Main entry point. Imports other modules, declares packages, shell config (fish/bash), editor (helix), git, SSH, kitty terminal, and services.
- **`hyprland.nix`** — Hyprland window manager configuration, keybindings, and related packages (grimblast, eww, bemenu).
- **`firefox.nix`** / **`librewolf.nix`** — Browser configurations with extensions and settings.
- **`vscode.nix`** — VS Code extensions and settings.
- **`starship.nix`** — Starship prompt configuration (imported as a value, not a module).
- **`nixpkgs-config.nix`** — Shared nixpkgs config (allowUnfree, etc.), used both by HM and standalone nix commands.
- **`files/`** — Static config files managed via `xdg.configFile` or `home.file`:
  - `eww/` — Eww widget bar (yuck/scss) with scripts for workspace/audio/window info.
  - `firefox/` — Custom CSS (tree-style-tab).
  - `fontconfig/` — Font configuration.
  - `swaylock/` — Custom swaylock effect (C source).
- **`private/`** — Optional directory (not committed) for sensitive config: SSH host configs (`private/ssh/config`) and GPG key fingerprint (`private/gpg-key-fingerprint`). Code checks `builtins.pathExists` before using these.

## Conventions

- Commit messages use **gitmoji** format (emoji prefix, e.g. `✨`, `🔧`, `👽️`) with a scope in parentheses.
- The configuration targets NixOS 25.11 (unstable channel) with Home Manager state version 23.11.
- Nix experimental features `nix-command` and `flakes` are enabled.
- Default editor is Helix (`hx`), default shell is Fish.
