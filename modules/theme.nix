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
      # bat, fish and fzf deliberately absent -- see the ANSI note below.
      helix.enable = true;
      # delta deliberately absent -- see the note below.
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

    # Colour that the TERMINAL owns, not that the programme bakes in.
    #
    # A programme emitting truecolour writes fixed hex into the terminal's
    # cells. That has three consequences, all of them bad here:
    #   1. Scrollback is permanent. Output printed before a darkman switch keeps
    #      the old flavour forever; nothing can recolour it.
    #   2. Long-running processes go stale. fish read its theme once at shell
    #      startup, so a shell open across a transition rendered Frappe
    #      foregrounds on Latte's background -- measured at 1.35:1, about twice
    #      as bad as Latte's own palette problem.
    #   3. Contrast becomes unfixable in one place, since every programme
    #      carries its own copy of the colours.
    # ANSI-indexed output has none of these: the cell stores an index, kitty
    # resolves it at draw time, so scrollback recolours on switch, nothing can
    # be stale, and one edit to programs.kitty.settings reaches everything.
    #
    # So bat uses base16 (basic SGR plus the bright slots -- all sixteen are
    # palette entries) and fish uses its built-in defaults, which are also
    # ANSI. Both are then variant-independent, which is why neither appears in
    # the catppuccin block above. NB base16-256 is NOT equivalent: it reaches
    # into the fixed 6x6x6 cube, which no flavour change touches.
    #
    # The cost is fewer distinct hues than a bespoke truecolour theme. Measured
    # on fish, that trade was strongly favourable: every syntax element on the
    # command line went from 2.30-2.96:1 to clearing 4.5:1.
    programs.bat.config.theme = "base16";

    # Whichever two ANSI grey slots hug the background move one step along the
    # ramp, away from it.
    #
    # ANSI slot names are absolute -- 0 is black through 15 is bright white --
    # and both flavours order them that way by lightness. What differs is which
    # end the background sits at, so which pair goes quiet flips with the
    # variant:
    #
    #             background L   near-background pair        contrast
    #   Latte        0.958       color7, color15             1.91, 1.61
    #   Frappe       0.329       color8, color0              2.23, 1.72
    #
    # That is correct by the convention, not a palette bug. The problem is that
    # base16 themes use those slots as FOREGROUNDS -- bat draws punctuation with
    # color7 on Latte (153 cells in one frame) and line numbers with color8 on
    # Frappe -- so on each variant the two slots nearest the background end up
    # carrying text. Shifting each one step lifts them without turning structure
    # into body text: the slot that carries the most text lands on overlay0 in
    # both flavours, at dL 0.250 on Latte and 0.252 on Frappe. The same
    # perceptual quietness from mirrored slots, which is why this is expressed
    # as a rule rather than two hand-tuned pairs.
    #
    # Tokens rather than hand-picked hex on purpose. The ramp is a designed
    # curve in hue AND chroma -- 264.5 deg at base to 279.3 at text, with chroma
    # rising 4x -- so a value generated by darkening keeps its source's chroma
    # and lands ~15% under-saturated for its new lightness. The tokens sit on
    # the curve by definition.
    #
    # These are deliberately NOT pushed to WCAG AA. They are structure --
    # brackets, separators, box drawing -- which should stay subordinate to text
    # you actually read. Kept ~3:1 clear of the foreground for that reason.
    #
    # The accents are deliberately untouched. A uniform contrast target is
    # self-defeating: a contrast ratio IS a luminance measure, so forcing every
    # accent to 4.5:1 forces them all to the same lightness. Measured, mean
    # accent-to-accent contrast collapses from 1.49 to 1.02 and the palette reads
    # as one dark mass -- chroma barely moves, so it is the lightness spread that
    # is lost, not saturation.
    #
    # Works because kitty takes the last directive and home-manager's settings
    # are emitted after the Catppuccin include.
    programs.kitty.settings =
      if isLight then
        {
          color7 = config.theme.palette.overlay0; # 1.91 -> 2.30
          color15 = config.theme.palette.surface2; # 1.61 -> 1.91
        }
      else
        {
          color8 = config.theme.palette.overlay0; # 2.23 -> 2.87
          color0 = config.theme.palette.surface2; # 1.72 -> 2.23
        };

    # delta uses its OWN defaults, told only which way the background goes.
    #
    # catppuccin.delta pulled in a gitconfig defining every decoration as hex,
    # which measured worse than delta's defaults once delta knew the background
    # was light. Measured on one commit, worst-pair contrast:
    #
    #                              Latte              Frappe
    #   catppuccin feature         2.42  5 sub-AA     2.91  1 sub-AA
    #   bare defaults              1.06  7            3.28  2
    #   defaults + light/dark      2.61  4            3.28  2   <- this
    #
    # Bare defaults are the trap: with no config delta assumes a dark terminal
    # and paints near-black diff backgrounds on Latte, hence 1.06:1. One flag
    # fixes that. On Frappe the flag is a no-op -- delta already assumes dark --
    # so it is set from isLight rather than conditionally omitted, to keep the
    # two variants symmetric and the intent legible.
    #
    # This also drops a whole theme source: no more catppuccin-delta include.
    #
    # The syntax theme is kept separately, because decorations and syntax turn
    # out to be independent choices and the catppuccin feature conflated them.
    # With delta's own decorations, varying only the syntax theme on the same
    # diff:
    #
    #                          Latte  worst/subAA/sub3   Frappe
    #   gruvbox-light           3.30  5  0               (n/a)
    #   Catppuccin              2.96  5  1               4.53  0  0   <- this
    #   delta default / GitHub  2.61  4  1               3.28  2  0
    #   OneHalfLight/Dark       1.08  7  4               2.66  2  1
    #
    # Catppuccin makes delta flawless on Frappe -- the only configuration in the
    # whole audit with nothing below AA -- and beats delta's default on Latte's
    # worst pair. gruvbox-light wins Latte outright, but is a different family
    # in the diff view; Latte's residual 2.96 is its own green, which no
    # truecolour theme choice escapes.
    #
    # Note OneHalf{Light,Dark}, which this config pinned for years to "match
    # Catppuccin's muted feel", is the *worst* option measured -- 1.08:1.
    #
    # No dependency on bat's theme cache: bat 0.26 bundles all four Catppuccin
    # themes, so delta resolves them whether or not `bat cache --build` has run.
    #
    # NB delta's decorations stay truecolour either way, so its output remains
    # baked into scrollback. base16 would make it palette-following but measures
    # worse (1.91 on Latte), and for a structural reason rather than a tunable
    # one: base16 draws code with color7/color15, which are deliberately quiet
    # here because bat uses them for punctuation. One slot cannot be both quiet
    # structure and readable code.
    programs.delta.options = {
      light = isLight;
      syntax-theme = if isLight then "Catppuccin Latte" else "Catppuccin Frappe";
    };

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
