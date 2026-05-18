---
name: add-package
description: Add a package to modules/packages.nix in the right category, alphabetized
disable-model-invocation: true
---

# Add Package

Add a package to `modules/packages.nix`. The file groups packages into five lists, each opened with `with pkgs;`:

- `fonts` — fonts (`nerd-fonts.*`, `cm_unicode`, ...)
- `cliTools` — terminal tools (`bat`, `ripgrep`, `eza`, ...)
- `apps` — GUI apps and daemons (`pavucontrol`, `pinentry-all`, ...)
- `gaming` — games and launchers
- `mediaTools` — audio/video/image processing tools

## Steps

1. Read `modules/packages.nix` to see current categorization.
2. Decide which list the package belongs in. If genuinely ambiguous, ask the user.
3. Insert the bare package name (no `pkgs.` prefix — the `with pkgs;` scope is already open) on its own line, alphabetically among siblings.
4. Show the diff. Do not commit.

## Notes

- For attribute-path packages like `nerd-fonts.fira-code`, alphabetize by full path.
- If the package is unfree, no extra config is needed — `nixpkgs-config.nix` already sets `allowUnfree`.
- The user will run `home-manager build` (and then `switch`) themselves.
