{ lib, config, ... }:
let
  isLight = config.theme.variant == "latte";
  palette = config.theme.palette;
in
{
  config = {
    programs.fish = {
      enable = true;
      # Catppuccin Latte's fish theme uses flamingo (#dd7878) for params
      # and pink (#ea76cb) for redirection/operator — both ~2.5:1 on the
      # #eff1f5 background. The grays (overlay0 #9ca0b0) are similarly
      # faint. Replace with darker shades that preserve the original
      # warm/cool hue split:
      #   - params:                darker flamingo (off-palette)
      #   - redirection/operator:  darker pink     (off-palette)
      #   - grays/autosuggestion:  subtext0 (palette, ~4.7:1)
      # Frappe (dark) reads fine and is left alone.
      interactiveShellInit = lib.optionalString isLight ''
        set -g fish_color_param '#b85555'
        set -g fish_color_redirection '#c14ba2'
        set -g fish_color_operator '#c14ba2'
        set -g fish_color_gray '${palette.subtext0}'
        set -g fish_color_autosuggestion '${palette.subtext0}'
        set -g fish_color_comment '${palette.subtext0}'
        set -g fish_pager_color_progress '${palette.subtext0}'
        set -g fish_pager_color_prefix '#c14ba2'
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
