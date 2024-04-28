{ nix, pkgs, ... }:

{

  imports = [
    ./hyprland.nix
    ./firefox.nix
    ./librewolf.nix
  ];

  config = {

    nix = {
      package = pkgs.nix;
      settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
    };

    # Home Manager needs a bit of information about you and the paths it should
    # manage.
    home.username = "abclop99";
    home.homeDirectory = "/home/abclop99";

    # Manage XDG directories
    xdg.enable = true;
    xdg.userDirs.enable = true;
    xdg.userDirs.createDirectories = true;

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
      pavucontrol    # Audio control panel

      bat            # Fancy `cat` clone
      uutils-coreutils-noprefix   # Rust rewrite of GNU coreutils
      ripgrep        # Better grep in rust
      eza            # Better ls
      mosh           # Mobile shell: smarter SSH
      feh            # Image viewer
      mpv            # Command line media player
      mpc-cli        # CLI interface for MPD
      zathura        # PDF reader
      zellij         # Terminal multiplexer and session thing
      wl-clipboard   # Copy and paste
      git-annex      # Manage files between remotes with git

      nil            # Nix lsp for helix

      keepassxc      # Password manager
      glxinfo        # For glxgears to force screen to update every frame instead of delayed by 1 frame

      # (blender.override { cudaSupport = true; })        # VR Interview work & 3D modeling
      blender
      multiviewer-for-f1 # F1 Multiviewer for watching F1 & stuff (unfree)
      zoom-us         # Video meetings
      prismlauncher   # Minceraft launcher
      calibre         # Ebook reader and manager
    ];

    ## Configure shell
    # Use Fish shell
    programs.fish = {
      enable = true;
      shellAliases = {
        eza = "eza --icons=auto --dereference --color-scale=all --group --smart-group --header";
      };
      shellAbbrs = {
        ls = "eza";
        ll = "eza -l";
        la = "eza -a";
        lla = "eza -laa";

        tree = "eza --tree";

        ga = "git annex";
      };
    };
    #
    # Enable atuin in Fish
    programs.atuin = {
      enable = true;
      enableFishIntegration = true;
    };
    programs.fzf = {
      enable = true;
      enableFishIntegration = true;
      enableBashIntegration = true;
    };
    # Enable zoxide (better cd)
    programs.zoxide = {
      enable = true;
      enableFishIntegration = true;
      enableBashIntegration = true;
      options = [
        "--cmd cd"
      ];
    };
    # Starship prompt
    programs.starship = {
      enable = true;
      enableFishIntegration = true;
      enableBashIntegration = true;
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
      enableBashIntegration = true;
    };

    # SSH config
    programs.ssh = {
      enable = true;
      compression = true;
      controlMaster = "auto";
      forwardAgent = true;
      extraConfig = if (builtins.pathExists ./private/ssh/config) then 
        (builtins.readFile ./private/ssh/config)
      else
        ""
      ;
    };

    # Virtual terminal program
    programs.kitty = {
      enable = true;
      shellIntegration.enableFishIntegration = true;
      shellIntegration.enableBashIntegration = true;
      settings = {
        tab_bar_style = "powerline";
        tab_powerline_style = "slanted";
        tab_title_max_lenth = 16;

        background_opacity = "0.9";

        disable_ligatures = "cursor";
      };

      font = {
        name = "FiraCode Nerd Font";
        package = pkgs.nerdfonts.override {
          fonts = [
            "FiraCode"
            "VictorMono"
            "NerdFontsSymbolsOnly"
          ];
        };
      };

      theme = "Catppuccin-Frappe";
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
          whitespace.render = {
            nbsp = "all";
          };
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
      signing = if (builtins.pathExists ./private/gpg-key-fingerprint) then {
        signByDefault = true;
        key = (builtins.readFile ./private/gpg-key-fingerprint);
      } else {
        key = null;
      };

      # Delta syntax highlighter
      delta.enable = true;

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

    # Gammastep: blue light filter
    services.gammastep =
    let 

      # location = if (builtins.pathExists ./private/location.json ) then {
      #   f = builtins.fromJSON( builtins.readFile( ./private/location.json ));
      # } else {
      #   longitude = null;
      #   latitude = null;
      # };
      # # location = builtins.fromJSON( builtins.readFile( ./private/location.json ) );

      # key = if builtins.pathExists ./path then "woot" else "bummer";

      location = if (builtins.pathExists ./private/location.json ) then
        builtins.fromJSON( builtins.readFile( ./private/location.json ))
      else {
        longitude = null;
        latitude = null;
      };
    in
    {
      enable = true;
      provider = "geoclue2";
      latitude = location.latitude;
      longitude = location.longitude;
    };

    # Syncthing: syncs files between computers
    services.syncthing = {
      enable = true;
      tray.enable = true;
    };

    # Media player daemon
    services.mpd = {
      enable = true;
    };

    # udisk2 front-end with auto-mount
    services.udiskie.enable = true;
    # In configuration.nix: services.udisks2.enable = true;

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

    # Nixpkgs config file
    nixpkgs.config = import ./nixpkgs-config.nix;
    xdg.configFile."nixpkgs/config.nix".source = ./nixpkgs-config.nix;

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
    services.home-manager.autoUpgrade = {
      enable = true;
      frequency = "weekly";
    };

  };
}
