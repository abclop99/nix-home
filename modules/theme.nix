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
      # catppuccin.hyprland disabled: v26.05 themes via an inline-lua colors block
      # (require('themes.catppuccin')) that only renders under configType = "lua";
      # with our pinned "hyprlang" it emits an invalid `colors { _var { … } }`
      # block. We don't reference its color vars, so dropping it loses nothing.
    };

    gtk = {
      enable = true;
      theme = {
        name = gtkName;
        package = gtkPkg;
      };
      # 26.05 changed gtk4.theme default to null; keep GTK4 mirroring the GTK theme.
      gtk4.theme = config.gtk.theme;
      gtk3.extraConfig.gtk-application-prefer-dark-theme = !isLight;
    };

    dconf.settings."org/gnome/desktop/interface" = {
      color-scheme = "prefer-${colorScheme}";
    };

    # Route the XDG-portal Settings interface (org.freedesktop.appearance
    # color-scheme) to darkman, so portal-aware apps that "follow system"
    # (Qt/Flutter/Electron — e.g. RustDesk) actually observe dark/light. The
    # dconf setting above only reaches apps that read gsettings/dconf directly
    # (libadwaita); portal-based apps query org.freedesktop.portal.Settings,
    # which had NO backend here — xdg-desktop-portal-hyprland implements no
    # Settings interface, and darkman's own darkman.portal ships UseIn=sway
    # (never auto-selected under Hyprland). Naming darkman explicitly overrides
    # UseIn; its daemon already owns org.freedesktop.impl.portal.desktop.darkman
    # and reports its live mode. NB: this file FULLY REPLACES the system
    # hyprland-portals.conf (first match wins, no merge), so default=hyprland;gtk
    # is restated to keep ScreenCast/Screenshot/GlobalShortcuts routed.
    xdg.configFile."xdg-desktop-portal/hyprland-portals.conf".text = ''
      [preferred]
      default=hyprland;gtk
      org.freedesktop.impl.portal.Settings=darkman
    '';

    # delta highlights diff tokens with its OWN embedded theme set, which does
    # not include any Catppuccin theme (catppuccin/nix only registers those for
    # standalone bat). Naming "Catppuccin <flavor>" makes delta warn
    # ("Unknown theme ...") and fall back to its default, so pin a delta
    # built-in per variant. OneHalf{Light,Dark} matches Catppuccin's muted feel.
    programs.delta.options.syntax-theme =
      if isLight then "OneHalfLight" else "OneHalfDark";

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
