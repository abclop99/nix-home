{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib) mkOption types;

  isLight = config.theme.variant == "latte";
  colorScheme = if isLight then "light" else "dark";

  paletteLatte = {
    base = "#eff1f5";
    mantle = "#e6e9ef";
    surface0 = "#ccd0da";
    surface1 = "#bcc0cc";
    surface2 = "#acb0be";
    text = "#4c4f69";
    subtext0 = "#6c6f85";
    overlay0 = "#9ca0b0";
    red = "#d20f39";
    peach = "#fe640b";
    yellow = "#df8e1d";
    green = "#40a02b";
    teal = "#179299";
    sky = "#04a5e5";
    blue = "#1e66f5";
    mauve = "#8839ef";
  };

  paletteFrappe = {
    base = "#303446";
    mantle = "#292c3c";
    surface0 = "#414559";
    surface1 = "#51576d";
    surface2 = "#626880";
    text = "#c6d0f5";
    subtext0 = "#a5adce";
    overlay0 = "#737994";
    red = "#e78284";
    peach = "#ef9f76";
    yellow = "#e5c890";
    green = "#a6d189";
    teal = "#81c8be";
    sky = "#99d1db";
    blue = "#8caaee";
    mauve = "#ca9ee6";
  };

  # nixpkgs passes --name Catppuccin-GTK to upstream install.sh, so the theme
  # directories are Catppuccin-GTK-Light and Catppuccin-GTK-Dark-Frappe.
  gtkPkg =
    if isLight then
      pkgs.magnetic-catppuccin-gtk.override { shade = "light"; }
    else
      pkgs.magnetic-catppuccin-gtk.override {
        shade = "dark";
        tweaks = [ "frappe" ];
      };
  gtkName = if isLight then "Catppuccin-GTK-Light" else "Catppuccin-GTK-Dark-Frappe";

  locationFile = ../private/location.nix;
  location =
    if builtins.pathExists locationFile then
      import locationFile
    else
      throw "Create ${toString locationFile} with `{ latitude = <num>; longitude = <num>; }` before enabling darkman.";
in
{
  options.theme = {
    variant = mkOption {
      type = types.enum [
        "latte"
        "frappe"
      ];
      default = "frappe";
      description = "Catppuccin theme variant: latte (light) or frappe (dark).";
    };
    palette = mkOption {
      type = types.attrsOf types.str;
      readOnly = true;
      description = "Color tokens derived from theme.variant.";
    };
  };

  config = {
    theme.palette = if isLight then paletteLatte else paletteFrappe;

    # Opt-in per-app rather than catppuccin.enable=true: the global flag
    # auto-enables every submodule, which conflicts with the user's existing
    # qt.platformTheme.name="gtk" and the firefox extension config.
    catppuccin = {
      flavor = config.theme.variant;
      kitty.enable = true;
      bat.enable = true;
      fish.enable = true;
      fzf.enable = true;
      helix.enable = true;
      delta.enable = true;
      atuin.enable = true;
      zellij.enable = true;
      zathura.enable = true;
      mpv.enable = true;
      thunderbird.enable = true;
      hyprland.enable = true;
    };

    gtk = {
      enable = true;
      theme = {
        name = gtkName;
        package = gtkPkg;
      };
      gtk3.extraConfig.gtk-application-prefer-dark-theme = !isLight;
    };

    dconf.settings."org/gnome/desktop/interface" = {
      color-scheme = "prefer-${colorScheme}";
    };

    # The catppuccin-latte delta feature uses bat's "Catppuccin Latte" syntax
    # theme for diff tokens; its muted colors wash out against the pink/green
    # diff backgrounds. Use a darker, high-contrast theme for the light
    # variant; keep Catppuccin Frappe for dark.
    programs.delta.options.syntax-theme =
      if isLight then "GitHub" else "Catppuccin Frappe";

    # `dark` mirrors the base config (frappe). Declared so commands like
    # `home-manager switch --specialisation (darkman get)` work symmetrically.
    specialisation.dark.configuration = {
      theme.variant = "frappe";
    };
    specialisation.light.configuration = {
      theme.variant = "latte";
    };

    services.darkman = {
      enable = true;
      settings = {
        lat = location.latitude;
        lng = location.longitude;
        usegeoclue = false;
      };
      # gsettings broadcast is omitted: org.gnome.desktop.interface schema
      # isn't registered on this system (no gnome-settings-daemon). HM's
      # activation phase writes the color-scheme directly to dconf, which
      # libadwaita apps observe on next launch.
      darkModeScripts.switch-theme = ''
        set -euo pipefail
        trap '${pkgs.libnotify}/bin/notify-send -u critical "theme switch failed" "dark mode"' ERR
        export PATH=${pkgs.nix}/bin:$PATH
        ${config.home.profileDirectory}/bin/home-manager switch \
          --flake /home/abclop99/.config/home-manager#abclop99 \
          --specialisation dark
        ${pkgs.eww}/bin/eww reload || true
      '';
      lightModeScripts.switch-theme = ''
        set -euo pipefail
        trap '${pkgs.libnotify}/bin/notify-send -u critical "theme switch failed" "light mode"' ERR
        export PATH=${pkgs.nix}/bin:$PATH
        ${config.home.profileDirectory}/bin/home-manager switch \
          --flake /home/abclop99/.config/home-manager#abclop99 \
          --specialisation light
        ${pkgs.eww}/bin/eww reload || true
      '';
    };
  };
}
