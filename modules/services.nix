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
    };

    services.home-manager.autoExpire.enable = true;

    nix.gc = {
      automatic = true;
      dates = "monthly";
      options = "--delete-older-than 30d";
    };
  };
}
