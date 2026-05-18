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
    zathura
    zellij
    mpv
    mpc
    qmk
    qmk-udev-rules
    micromamba
  ];

  gaming = with pkgs; [
    lutris
    wineWowPackages.waylandFull
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
  };
}
