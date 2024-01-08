{ pkgs, ... }:

{

  imports = [
    ./hyprland.nix
  ];

  config = {

    # Home Manager needs a bit of information about you and the paths it should
    # manage.
    home.username = "abclop99";
    home.homeDirectory = "/home/abclop99";

    # Manage XDG directories
    xdg.enable = true;

    # This value determines the Home Manager release that your configuration is
    # compatible with. This helps avoid breakage when a new Home Manager release
    # introduces backwards incompatible changes.
    #
    # You should not change this value, even if you update Home Manager. If you do
    # want to update the value, then make sure to first check the Home Manager
    # release notes.
    home.stateVersion = "23.11"; # Please read the comment before changing.

    # The home.packages option allows you to install Nix packages into your
    # environment.
    home.packages = with pkgs; [
      # # Adds the 'hello' command to your environment. It prints a friendly
      # # "Hello, world!" when run.
      # pkgs.hello

      # # It is sometimes useful to fine-tune packages, for example, by applying
      # # overrides. You can do that directly here, just don't forget the
      # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
      # # fonts?
      (nerdfonts.override { fonts = [ "FiraCode" "VictorMono" "NerdFontsSymbolsOnly" ]; })
      font-awesome      # Symbols
      cm_unicode        # Computer Modern with unicode stuff

      # # You can also create simple shell scripts directly inside your
      # # configuration. For example, this adds a command 'my-hello' to your
      # # environment:
      # (pkgs.writeShellScriptBin "my-hello" ''
      #   echo "Hello, ${config.home.username}!"
      # '')

      pinentry       # GPG passphrase input

      bat            # Fancy `cat` clone
      ripgrep        # Better grep in rust
      tree           # tree view ls thing

      nil            # Nix lsp for helix
    ];

    ## Configure shell
    # Use Fish shell
    programs.fish.enable = true;
    # Enable atuin in Fish
    programs.atuin = {
      enable = true;
      enableFishIntegration = true;
    };
    # Starship prompt
    programs.starship = {
      enable = true;
      enableFishIntegration = true;
      enableTransience = true;
      settings = {
        "$schema" = "https://starship.rs/config-schema.json";
        right_format = "$status$cmd_duration$time";
        os = {
          disabled = false;
          symbols.Arch = "";
        };
        shell.disabled = false;
        status.disabled = false;
        sudo.disabled = false;
        time.disabled = false;
      };
    };
    # `thefuck` corrects previous command
    programs.thefuck = {
      enable = true;
      enableFishIntegration = true;
    };

    # Virtual terminal program
    programs.kitty = {
      enable = true;
      shellIntegration.enableFishIntegration = true;
      settings = {
        tab_bar_style = "powerline";
        tab_powerline_style = "slanted";
        tab_title_max_lenth = 16;

        background_opacity = "0.9";

        disable_ligatures = "cursor";
      };

      font = {
        name = "VictorMono Nerd Font";
      };
    };

    # Helix configuration
    programs.helix = {
      enable = true;
      defaultEditor = true;
      # Settings
      settings = {
        editor = {
          line-number = "relative";
          cursorline = true;
          cursorcolumn = true;
          rulers = [80];
          text-width = 80;
          bufferline = "multiple";
          cursor-shape = {
            insert = "bar";
            normal = "block";
            select = "underline";
          };
          indent-guides.render = true;
          soft-wrap.enable = true;
          lsp.display-messages = true;
          statusline.left = ["mode" "spinner" "version-control" "file-name"];
        };
        keys = {
          normal.X = ["extend_line_up" "extend_to_line_bounds"];
          select.X = ["extend_line_up" "extend_to_line_bounds"];
        };
      };
    };

    # git
    programs.git = {
      enable = true;

      userName = "Aaron Li";
      userEmail = "a1li@ucsd.edu";

      # Enable signing if key is given in a file
      signing = if (builtins.pathExists ./gpg-key-fingerprint.secret) then {
        signByDefault = true;
        key = (builtins.readFile ./gpg-key-fingerprint.secret);
      } else {
        key = null;
      };

      extraConfig = {
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
      };
    };

    # GPG
    programs.gpg = {
      enable = true;
    };

    services.gnome-keyring = {
      enable = true;
    };

    # Firefox
    programs.firefox = {
      enable = true;
      # TODO: profile settings, such as userchrome, extensions, etc.
    };

    # Home Manager is pretty good at managing dotfiles. The primary way to manage
    # plain files is through 'home.file'.
    home.file = {
      # # Building this configuration will create a copy of 'dotfiles/screenrc' in
      # # the Nix store. Activating the configuration will then make '~/.screenrc' a
      # # symlink to the Nix store copy.
      # ".screenrc".source = dotfiles/screenrc;

      # # You can also set the file content immediately.
      # ".gradle/gradle.properties".text = ''
      #   org.gradle.console=verbose
      #   org.gradle.daemon.idletimeout=3600000
      # '';
    };

    # Enable fontconfig discovering fonts
    fonts.fontconfig.enable = true;
    # Manual fontconfig configuration because HM doesn't do it
    xdg.configFile."fontconfig/fonts.conf".source = ./files/fontconfig/fonts.conf;

    # Home Manager can also manage your environment variables through
    # 'home.sessionVariables'. If you don't want to manage your shell through Home
    # Manager then you have to manually source 'hm-session-vars.sh' located at
    # either
    #
    #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
    #
    # or
    #
    #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
    #
    # or
    #
    #  /etc/profiles/per-user/abclop99/etc/profile.d/hm-session-vars.sh
    #
    home.sessionVariables = {
      EDITOR = "hx";
    };

    # Let Home Manager install and manage itself.
    programs.home-manager.enable = true;

  };
}
