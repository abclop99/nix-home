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
      enable = true;
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
