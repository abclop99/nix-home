{ pkgs, ... }:
{
  config = {
    programs.kitty = {
      enable = true;
      shellIntegration.enableFishIntegration = true;
      shellIntegration.enableBashIntegration = true;
      settings = {
        tab_bar_style = "powerline";
        tab_powerline_style = "slanted";
        tab_title_max_length = 16;

        # Use the "splits" layout: new windows (ctrl+shift+enter) split the
        # focused pane, direction chosen by aspect ratio (wide -> left/right,
        # tall -> top/bottom). Splits is listed first, so it is the default.
        # ctrl+shift+l cycles all three. "stack" is the fullscreen "zoom"
        # layout, also toggled directly with ctrl+shift+z (below); it must be
        # in this list for that toggle to work (toggle_layout delegates to
        # goto_layout, which only accepts enabled layouts).
        enabled_layouts = "splits:split_axis=auto,grid,stack";

        background_opacity = "0.9";

        disable_ligatures = "cursor";

        # Kitty's default (0.4) blends ANSI dim text 60% into the bg,
        # which makes chalk.dim() output (e.g. Claude Code's "Resume
        # this session with…") unreadable on Catppuccin backgrounds.
        dim_opacity = "0.75";
      };

      keybindings = {
        # Toggle the focused window to fullscreen ("zoom") and back.
        "ctrl+shift+z" = "toggle_layout stack";
      };

      font = {
        name = "Fira Code";
        package = pkgs.fira-code;
      };
    };
  };
}
