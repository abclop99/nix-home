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
        tab_title_max_lenth = 16;

        background_opacity = "0.9";

        disable_ligatures = "cursor";
      };

      font = {
        name = "Fira Code";
        package = pkgs.fira-code;
      };
    };
  };
}
