{ pkgs, lib, ... }:

let
  # Server coordinates live in a skip-worktree'd private file (placeholder in
  # git, real values on disk). See private/rustdesk.nix and CLAUDE.md.
  priv = import ../private/rustdesk.nix;

  # RustDesk stores server + auth options in RustDesk2.toml. api-server is
  # omitted: the OSS server doesn't need it, and a literal empty '' would
  # collide with Nix's '' string-escape inside this multiline string.
  rustdesk2Toml = pkgs.writeText "RustDesk2.toml" ''
    [options]
    custom-rendezvous-server = '${priv.rendezvousServer}'
    relay-server = '${priv.relayServer}'
    key = '${priv.key}'
    verification-method = 'use-permanent-password'
    approve-mode = 'password'
  '';
in
# Stay completely inert until real server values exist: a blank
# custom-rendezvous-server would make RustDesk silently fall back to its PUBLIC
# servers. The rustdesk-flutter *package* is installed unconditionally in
# packages.nix; only the config + autostart are gated here.
lib.mkIf (priv.rendezvousServer != "") {
  # Point the client at the self-hosted server and enable unattended (password)
  # access. RustDesk rewrites RustDesk2.toml at runtime, so it must be a MUTABLE
  # copy — a read-only /nix/store symlink breaks RustDesk's writes. Install it
  # once, only if absent, so runtime edits (and the permanent password set via
  # `rustdesk --password`, which lives in the separate RustDesk.toml) persist.
  home.activation.rustdeskConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfg="$HOME/.config/rustdesk/RustDesk2.toml"
    if [ ! -e "$cfg" ]; then
      $DRY_RUN_CMD mkdir -p "$HOME/.config/rustdesk"
      $DRY_RUN_CMD install -m600 ${rustdesk2Toml} "$cfg"
    fi
  '';

  # Pre-tick the screencast "Allow restore token" so unattended RustDesk
  # reconnects don't re-prompt the Hyprland portal picker. This is xdph's OWN
  # backend config (Hyprlang format) read from ~/.config/hypr/xdph.conf — NOT
  # the frontend routing file, and the key is `screencopy` (not `screencast`).
  # RustDesk must still request persist_mode for a token to be created (it does).
  # The Settings→darkman portal *routing* lives in modules/theme.nix.
  xdg.configFile."hypr/xdph.conf".text = ''
    screencopy {
        allow_token_by_default = true
    }
  '';

  # Run RustDesk headless inside the graphical session so the machine is reachable
  # unattended. `--server` (not the bare GUI) is deliberate:
  #   - The plain GUI opens a maximized window that home-manager `switch` re-spawns
  #     on every activation (darkman sun-transitions, manual hm-switch, auto-upgrade):
  #     closing the intrusive window leaves the unit stopped, so sd-switch restarts
  #     it each time. `--server` runs with NO window — nothing to pop up or close, so
  #     it stays running across switches and sd-switch leaves it alone.
  #   - The systray icon is a separate `rustdesk --tray` process the GUI only spawns
  #     when a standalone `--server` process exists (core_main.rs). `--server`
  #     auto-spawns it, so this one unit yields both the server and the tray.
  # It blocks in the foreground → Type=simple (default) tracks it; the --tray child
  # shares the cgroup and is cleaned up on stop. Open the full GUI on demand with
  # `rustdesk` (still on PATH via packages.nix) or the tray's "Open" item.
  # Mirrors the hyprpolkitagent user service in modules/hyprland.nix.
  systemd.user.services.rustdesk = {
    Unit = {
      Description = "RustDesk unattended server (headless)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStart = "${pkgs.rustdesk-flutter}/bin/rustdesk --server";
      Slice = "session.slice";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
