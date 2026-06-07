{ pkgs, ... }:

let
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
    calibre
    mpc
    qmk
    qmk-udev-rules
    micromamba
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
in
{
  config = {
    home.packages = fonts ++ cliTools ++ apps ++ gaming ++ mediaTools;

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
