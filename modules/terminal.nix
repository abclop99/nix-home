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

        background_opacity = "0.9";

        disable_ligatures = "cursor";

        # Kitty's default (0.4) blends ANSI dim text 60% into the bg,
        # which makes chalk.dim() output (e.g. Claude Code's "Resume
        # this session with…") unreadable on Catppuccin backgrounds.
        dim_opacity = "0.75";
      };

      font = {
        name = "Fira Code";
        package = pkgs.fira-code;
      };
    };
  };
}
