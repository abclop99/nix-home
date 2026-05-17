{ ... }:

{
  config = {
    programs.librewolf = {
      enable = true;

      settings = {
        # Manual config so the other proxy settings apply
        # For I2P
        "network.proxy.type" = 1;

        "network.proxy.allow_bypass" = false;

        "network.proxy.http" = "127.0.0.1";
        "network.proxy.http_port" = 4444;
        "network.proxy.share_proxy_settings" = true;

        "network.proxy.ssl" = "127.0.0.1";
        "network.proxy.ssl_port" = 4444;

        "media.peerConnection.ice.proxy_only" = true;

        # Disable I2P proxy for:
        "network.proxy.no_proxies_on" = "mozilla.org";

        # I2P doesn't usually use HTTPS
        "dom.security.https_only_mode" = false;
      };

     
    };
  };
}
