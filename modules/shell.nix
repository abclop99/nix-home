{ lib, config, ... }:
let
  isLight = config.theme.variant == "latte";
  palette = config.theme.palette;
in
{
  config = {
    programs.fish = {
      enable = true;
      # Catppuccin Latte's fish theme uses flamingo (#dd7878) for params,
      # pink (#ea76cb) for redirection/operator, and yellow (#df8e1d) for
      # quotes — all 2.3-2.6:1 on the #eff1f5 background, well under WCAG
      # AA (4.5:1). The grays (overlay0 #9ca0b0) are similarly faint.
      # Replace with darker shades that preserve the original warm/cool
      # hue split (ratios vs #eff1f5):
      #   - params:                darker flamingo #b85555  (4.16:1, near-AA)
      #   - redirection/operator:  darker pink     #a83389  (5.31:1, AA)
      #   - quotes:                darker amber    #8a5e00  (5.04:1, AA)
      #   - grays/autosuggestion:  subtext0        #6c6f85  (4.37:1, near-AA)
      # Frappe (dark) reads fine and is left alone.
      interactiveShellInit = lib.optionalString isLight ''
        set -g fish_color_param '#b85555'
        set -g fish_color_redirection '#a83389'
        set -g fish_color_operator '#a83389'
        set -g fish_color_quote '#8a5e00'
        set -g fish_color_gray '${palette.subtext0}'
        set -g fish_color_autosuggestion '${palette.subtext0}'
        set -g fish_color_comment '${palette.subtext0}'
        set -g fish_pager_color_progress '${palette.subtext0}'
        set -g fish_pager_color_prefix '#a83389'
        set -g fish_pager_color_description '${palette.subtext0}'
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
