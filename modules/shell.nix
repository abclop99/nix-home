{ ... }:
{
  config = {
    programs.fish = {
      enable = true;
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

        hm-switch = "home-manager switch --flake /home/abclop99/.config/home-manager#abclop99 --specialisation (darkman get)";
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
      # base16 restricts fzf to the terminal's sixteen palette slots. It is not
      # only about contrast: catppuccin.fzf puts hex into FZF_DEFAULT_OPTS,
      # which is exported at shell login, so a shell open across a darkman
      # switch runs even a brand-new fzf with the previous flavour's colours.
      # Being an environment variable makes it the most stubborn case of that
      # in this config -- worse than a config file, which at least gets re-read.
      defaultOptions = [ "--color=base16" ];
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
