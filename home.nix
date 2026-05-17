{ pkgs, ... }:
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
