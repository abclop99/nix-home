{ ... }:
{
  config = {
    services.gnome-keyring = {
      enable = true;
    };

    programs.thunderbird = {
      enable = true;
      profiles.default = {
        isDefault = true;
        withExternalGnupg = true;
      };
    };

    services.syncthing = {
      enable = true;
      tray.enable = true;
    };

    services.mpd = {
      enable = true;
    };

    services.udiskie.enable = true;

    services.home-manager.autoUpgrade = {
      # Disabled: this switches unattended over whatever network exists, but
      # large substitutions here stall without the VPN (cloudflare-warp fails
      # at boot). Worse, the script is `set -euo pipefail`, so a run that dies
      # after `nix flake update` leaves flake.lock advanced with nothing
      # switched — which breaks the next manual hm-switch too. Re-enable once
      # the nix *daemon* has a working proxy (system-level, /persist/etc/nixos).
      enable = false;
      useFlake = true;
      flakeDir = "/home/abclop99/.config/home-manager";
      frequency = "weekly";
      # HM 26.05 changed this default to [ ]; pin the pre-26.05 value so the
      # weekly auto-upgrade still runs nix flake update before switching.
      preSwitchCommands = [ "nix flake update" ];
    };

    services.home-manager.autoExpire.enable = true;

    nix.gc = {
      automatic = true;
      dates = "monthly";
      options = "--delete-older-than 30d";
    };
  };
}
