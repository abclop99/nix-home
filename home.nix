{ pkgs, inputs, ... }:
{
  imports = [
    ./modules/packages.nix
    ./modules/shell.nix
    ./modules/editor.nix
    ./modules/terminal.nix
    ./modules/git.nix
    ./modules/services.nix
    ./modules/hyprland.nix
    ./modules/rustdesk.nix
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
      # Raise the GitHub API rate limit (60→5000/hr) so `nix flake update` doesn't
      # 403 re-fetching the github: inputs. Token lives in a machine-local, non-repo,
      # non-store file (see CLAUDE.md "GitHub API token"), created out of band.
      #   - RELATIVE path on purpose: nix resolves includes against the dir of the
      #     config file it reads (~/.config/nix/), NOT the store symlink target. So
      #     this points at ~/.config/nix/github-access-tokens.conf with no absolute/
      #     username path. Do NOT "fix" this to an absolute path.
      #   - `!include` is the *optional-include* form (a missing file is skipped,
      #     not an error) — required twice over: at runtime a missing token file
      #     doesn't break nix, AND the HM build's checkPhase (nix config show, token
      #     file absent at build time) passes only with the bang. Plain `include`
      #     would fail the build. Do NOT drop the bang.
      #   - Do NOT move the token into nix.settings.access-tokens or manage the
      #     token file via home.file/xdg.configFile — that bakes the PAT into the
      #     world-readable /nix/store.
      extraOptions = ''
        !include github-access-tokens.conf
      '';
    };

    home.username = "abclop99";
    home.homeDirectory = "/home/abclop99";
    home.stateVersion = "23.11";

    xdg = {
      enable = true;
      userDirs = {
        enable = true;
        createDirectories = true;
        # 26.05 changed the default to false; pin true to keep exporting XDG_*_DIR vars.
        setSessionVariables = true;
      };
    };

    home.sessionVariables = {
      EDITOR = "hx";
    };

    # SSH config
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      settings."*" = {
        ForwardX11 = true;
        Compression = true;
        ControlMaster = "auto";
        ForwardAgent = true;
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
