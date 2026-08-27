{ pkgs, inputs, ... }:

let
  pkgs-unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = import ../nixpkgs-config.nix;
  };

  fonts = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.victor-mono
    nerd-fonts.symbols-only
    cm_unicode
    atkinson-hyperlegible
    libertinus
  ];

  cliTools = with pkgs; [
    uutils-coreutils-noprefix
    ripgrep
    semgrep
    eza
    mosh
    feh
    trashy
    usbutils
    wl-clipboard
    # On PATH purely so the filter can be driven by hand -- `hyprshade on
    # blue-light-filter`, `off`, `toggle`, `current`, `ls`. The schedule in
    # modules/hyprland.nix invokes ${pkgs.hyprshade}/bin/hyprshade by absolute
    # store path, so it worked without this and there was no command to type.
    # Deliberately nixpkgs' build rather than upstream's flake: this is the
    # same derivation the unit runs, so the CLI and the timer can never be
    # different versions, and it is the version built against this nixpkgs'
    # Hyprland.
    hyprshade
    yt-dlp
    nix-index
    nil
  ];

  apps = with pkgs; [
    pinentry-all
    pavucontrol
    keepassxc
    mesa-demos
    prismlauncher
    modrinth-app # Minecraft launcher; bundles jdk8/17/21/25 — see CLAUDE.md quirk
    calibre
    mpc
    qmk
    qmk-udev-rules
    micromamba
    rustdesk-flutter # Remote desktop → self-hosted server; config in modules/rustdesk.nix
  ];

  gaming = with pkgs; [
    antimicrox
  ];

  mediaTools = with pkgs; [
    gitmoji-cli
    git-annex
    atomicparsley
    exiftool
    vorbis-tools
  ];

  # Claude Code from nixpkgs-unstable — stable's claude-code is backported in
  # sporadic bursts and lags by weeks. Installed as a bare package, not via the
  # programs.claude-code HM module: no Claude config is managed through HM, and
  # importing the *unstable* module evaluates it against the stable lib, which
  # lacks lib.hm.strings.isPathLike (breaks eval). See CLAUDE.md.
  unstable = [ pkgs-unstable.claude-code ];
in
{
  config = {
    home.packages = fonts ++ cliTools ++ apps ++ gaming ++ mediaTools ++ unstable;

    # HM-managed so Catppuccin can theme them (see catppuccin.* in modules/theme.nix).
    programs.zellij = {
      enable = true;
      # Keybinds preserved verbatim from the pre-HM config — the repeated `bind`
      # nodes can't be expressed as a settings attrset, so they go through
      # extraConfig. Catppuccin theming is injected via catppuccin.zellij
      # (programs.zellij.settings) in modules/theme.nix.
      extraConfig = builtins.readFile ../files/zellij/keybinds.kdl;
    };
    programs.zathura.enable = true;
    programs.mpv.enable = true;
    # Without this there is no bat config file to write the theme into, and
    # bat silently renders in Monokai Extended under *both* variants. The
    # theme it now carries is base16 (modules/theme.nix), not a Catppuccin
    # one -- see the ANSI note there for why.
    programs.bat.enable = true;
  };
}
