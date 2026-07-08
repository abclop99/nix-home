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
    bat
    uutils-coreutils-noprefix
    ripgrep
    semgrep
    eza
    mosh
    feh
    trashy
    usbutils
    wl-clipboard
    yt-dlp
    nix-index
    nil
  ];

  apps = with pkgs; [
    pinentry-all
    pavucontrol
    keepassxc
    mesa-demos
    blender
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
    lutris
    wineWow64Packages.waylandFull
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
  };
}
