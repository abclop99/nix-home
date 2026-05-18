---
name: new-module
description: Scaffold a new modules/<name>.nix and wire its import into home.nix
disable-model-invocation: true
---

# New Module

Create a new Home Manager module under `modules/` and register it in `home.nix`.

## Steps

1. Take a module name from the user (kebab-case, no `.nix` suffix).
2. Verify `modules/<name>.nix` does not already exist.
3. Write `modules/<name>.nix` with the standard template:

   ```nix
   { pkgs, ... }:
   {
     config = {
       # ...
     };
   }
   ```

   Use `{ ... }` (no `pkgs`) if `pkgs` is not referenced.
4. Add `./modules/<name>.nix` to the `imports` list in `home.nix`. The list is not strictly alphabetical — place it near related modules (e.g. UI modules grouped together).
5. Show the diff. Do not commit.

## Notes

- The `config = { ... };` wrapper is the repo convention (see CLAUDE.md). Don't omit it.
- For modules that ship static files (yuck, conf, scss), reference them via `xdg.configFile."subdir/file".source = ../files/<path>;`.
- Don't add features beyond the scaffold — leave the body empty for the user to fill in.
