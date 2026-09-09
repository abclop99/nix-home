{ lib, pkgs, ... }:
let
  # Identity and signing key. These belong to whoever runs the config, not to
  # whoever wrote it, so they are skip-worktree'd: null placeholder in git,
  # real values on disk. See private/git.nix and CLAUDE.md "Private files".
  private = import ../private/git.nix;
in
{
  config = {
    programs.git = {
      enable = true;

      signing = if private.signingKey != null then {
        signByDefault = true;
        key = private.signingKey;
      } else {
        key = null;
      };

      settings = {
        # Dropped when null rather than written empty: an empty user.email
        # overrides git's own EMAIL fallback and records commits with no author
        # email, where an absent one lets the fallback work.
        user = lib.filterAttrs (_: v: v != null) {
          name = private.name;
          email = private.email;
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
