{ pkgs, inputs, ... }:
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

    programs.home-manager = {
      enable = true;
      # Patch HOME_MANAGER_PATH into the wrapper so the CLI's un-gated
      # `<home-manager/home-manager/build-news.nix>` lookup resolves via the
      # flake input instead of NIX_PATH (which won't contain home-manager
      # after channel removal). The CLI itself is auto-pinned to the same
      # nixpkgs revision that this config uses, since `programs.home-manager.package`
      # is read-only and derives from `pkgs.callPackage ../../home-manager`.
      path = "${inputs.home-manager}";
    };
  };
}
