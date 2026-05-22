{ lib, config, ... }:
let
  isLight = config.theme.variant == "latte";
  palette = config.theme.palette;
  # Catppuccin Latte upstream uses flamingo/pink/yellow/overlay0 for
  # these slots — all 2.3-2.6:1 on #eff1f5, well under WCAG AA (4.5:1).
  # Darker replacements: pink and yellow now clear AA; flamingo and the
  # gray sit ≈0.1-0.3 below but are still a large improvement. Frappe
  # reads fine and is untouched.
  darkFlamingo = "#b85555";          # 4.16:1 — param
  darkPink     = "#a83389";          # 5.31:1 — redirection / operator / pager prefix
  darkYellow   = "#8a5e00";          # 5.04:1 — quote
  darkGray     = palette.subtext0;   # 4.37:1 — grays / autosuggestion / comment
in
{
  config = {
    programs.fish = {
      enable = true;
      interactiveShellInit = lib.optionalString isLight ''
        set -g fish_color_param '${darkFlamingo}'
        set -g fish_color_redirection '${darkPink}'
        set -g fish_color_operator '${darkPink}'
        set -g fish_color_quote '${darkYellow}'
        set -g fish_color_gray '${darkGray}'
        set -g fish_color_autosuggestion '${darkGray}'
        set -g fish_color_comment '${darkGray}'
        set -g fish_pager_color_progress '${darkGray}'
        set -g fish_pager_color_prefix '${darkPink}'
        set -g fish_pager_color_description '${darkGray}'
      '';
      shellAliases = {
        eza = "eza --icons=auto --color-scale=all --group --smart-group --header";
      };
      shellAbbrs = {
        ls = "eza";
        ll = "eza -l";
        la = "eza -a";
        laa = "eza -aa";
        lla = "eza -laa";
        llaa = "eza -laa";

        tree = "eza --tree";

        ga = "git annex";

        icat = "kitten icat";

        youtube-download = "yt-dlp -x -f 'bestaudio[ext=m4a]' --add-metadata --embed-thumbnail --sponsorblock-remove music_offtopic";

        hm-switch = "home-manager switch --flake /home/abclop99/.config/home-manager#abclop99";
        hm-build = "home-manager build --flake /home/abclop99/.config/home-manager#abclop99";
      };
    };

    programs.bash = {
      enable = true;
      enableVteIntegration = true;
    };

    programs.atuin = {
      enable = true;
      enableFishIntegration = true;
    };

    programs.fzf = {
      enable = true;
      enableFishIntegration = true;
      enableBashIntegration = true;
    };

    programs.zoxide = {
      enable = true;
      enableFishIntegration = true;
      enableBashIntegration = true;
      options = [
        "--cmd cd"
      ];
    };

    programs.starship = import ./starship.nix;

    programs.pay-respects = {
      enable = true;
      enableFishIntegration = true;
      enableBashIntegration = true;
    };
  };
}
