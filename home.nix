{ pkgs, ... }:
let
  catppuccin = builtins.fetchTarball {
    url = "https://github.com/catppuccin/nix/archive/refs/tags/v25.11.tar.gz";
    sha256 = "07x6wna7nxbqlgnvcyck24lfvhh1z600s39sr6dlydhaxk5g0326";
  };
in
{
  imports = [
    ./modules/packages.nix
    ./modules/shell.nix
    ./modules/editor.nix
    ./modules/claude-code.nix
    ./modules/terminal.nix
    ./modules/git.nix
    ./modules/services.nix
    ./modules/hyprland.nix
    ./modules/firefox.nix
    ./modules/librewolf.nix
    ./modules/vscode.nix
    ./modules/theme.nix
    "${catppuccin}/modules/home-manager"
  ];

  config = {
    nix = {
      package = pkgs.nix;
      settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
    };

    home.username = "abclop99";
    home.homeDirectory = "/home/abclop99";
    home.stateVersion = "23.11";

    xdg = {
      enable = true;
      userDirs = {
        enable = true;
        createDirectories = true;
      };
    };

    home.sessionVariables = {
      EDITOR = "hx";
    };

    # SSH config
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      matchBlocks."*" = {
        forwardX11 = true;
        compression = true;
        controlMaster = "auto";
        forwardAgent = true;
      };

      extraConfig = if (builtins.pathExists ./private/ssh/config) then
        (builtins.readFile ./private/ssh/config)
      else
        ""
      ;
    };

    fonts.fontconfig.enable = true;
    xdg.configFile."fontconfig/fonts.conf".source = ./files/fontconfig/fonts.conf;

    nixpkgs.config = import ./nixpkgs-config.nix;
    xdg.configFile."nixpkgs/config.nix".source = ./nixpkgs-config.nix;

    programs.home-manager.enable = true;
  };
}
