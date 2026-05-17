{ pkgs, ... }:
{
  config = {
    programs.git = {
      enable = true;

      signing = if (builtins.pathExists ../private/gpg-key-fingerprint) then {
        signByDefault = true;
        key = (builtins.readFile ../private/gpg-key-fingerprint);
      } else {
        key = null;
      };

      settings = {
        user = {
          name = "Aaron Li";
          email = "a628li@uwaterloo.ca";
        };

        init.defaultBranch = "main";
        push.autoSetupRemote = true;
        safe.directory = "/persist/etc/nixos";
      };
    };

    programs.delta = {
      enable = true;
      enableGitIntegration = true;
    };

    xdg.configFile."gitmoji-nodejs/config.json".text = (builtins.toJSON {
      autoAdd = false;
      emojiFormat = "emoji";
      scopePrompt = true;
      messagePrompt = false;
      capitalizeTitle = true;
    });

    programs.gh = {
      enable = true;
      settings = {
        git_protocol = "ssh";
      };
      extensions = with pkgs; [
        gh-eco
        gh-markdown-preview
        gh-notify
      ];
    };

    programs.gpg = {
      enable = true;
    };
  };
}
