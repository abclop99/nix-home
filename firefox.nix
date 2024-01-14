{ pkgs, ... }:

{
  config = {
    # Need to include NUR
    nixpkgs.config = import ./nixpkgs-config.nix;

    # Firefox
    programs.firefox = {
      enable = true;
      # TODO: profile settings, such as userchrome, extensions, etc.

      profiles.default = {
        isDefault = true;

        extensions = with pkgs.nur.repos.rycee.firefox-addons; [
          # Basic UI
          multi-account-containers
          tree-style-tab

          # Theme
          theme-nord-polar-night

          # Privacy
          adnauseam
          decentraleyes
          facebook-container
          libredirect
          noscript
          privacy-badger

          # QOL
          darkreader
          dearrow
          sponsorblock
          ublacklist
          unpaywall

          # Customization
          violentmonkey

          # Integration
          keepassxc-browser
        ];

        # Multi-accout containers
        containers = {
          "Personal" = {
            id = 1;
            color = "blue";
            icon = "fingerprint";
          };
          "Work" = {
            id = 2;
            color = "orange";
            icon = "briefcase";
          };
          "Banking" = {
            id = 3;
            color = "green";
            icon = "dollar";
          };
          "Shopping" = {
            id = 4;
            color = "pink";
            icon = "cart";
          };
          "Entertainment" = {
            id = 5;
            color = "red";
            icon = "chill";
          };
          "Miscellaneous" = {
            id = 6;
            color = "yellow";
            icon = "circle";
          };
          "Search" = {
            id = 7;
            color = "turquoise";
            icon = "chill";
          };
          "Facebook" = {
            id = 255;
            color = "toolbar";
            icon = "fence";
          };
        };

        search = {
          default = "Bing";
          privateDefault = "Ecosia";
          force = true;

          engines = {
            "Nix Packages" = {
              urls = [{
                template = "https://search.nixos.org/packages";
                params = [
                  { name = "type"; value = "packages"; }
                  { name = "query"; value = "{searchTerms}"; }
                ];
              }];
              icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              definedAliases = [ "@np" ];
            };
            
            "NixOS Wiki" = {
              urls = [{ template = "https://nixos.wiki/index.php?search={searchTerms}"; }];
              iconUpdateURL = "https://nixos.wiki/favicon.png";
              updateInterval = 24 * 60 * 60 * 1000; # Every day
              definedAliases = [ "@nw" ];
            };

            "MyNixOS" = {
              urls = [{ template = "https://mynixos.com/search?search={searchTerms}"; }];
              iconUpdateURL = "https://mynixos.com/static/icons/nix-snowflake-white.svg";
              updateInterval = 24 * 60 * 60 * 1000; # Every day
              definedAliases = [ "@mynixos" ];
            };

            "Arch Wiki" = {
              urls = [{ template = "https://wiki.archlinux.org/index.php?search={searchTerms}"; }];
              iconUpdateURL = "https://wiki.archlinux.org/favicon.ico";
              updateInterval = 24 * 60 * 60 * 1000; # Every day
              definedAliases = [ "@aw" ];
            };

            "Lib.rs" = {
              urls = [{ template = "https://lib.rs/search?q={searchTerms}"; }];
              iconUpdateURL = "https://lib.rs/favicon.ico";
              updateInterval = 24 * 60 * 60 * 1000; # Every day
              definedAliases = [ "@rs" ];
            };

            "Ecosia" = {
              urls = [{ template = "https://www.ecosia.org/search?q={searchTerms}"; }];
              iconUpdateURL = "https://www.ecosia.org/static/icons/favicon.ico";
              updateInterval = 24 * 60 * 60 * 1000; # Every day
              definedAliases = [ "@e" "@ecosia" ];
            };

            "Bing".metaData.alias = "@b";
            "Google".metaData.alias = "@g";
          };
        };

        settings = {
          # Extensions
          "extensions.activeThemeID" = pkgs.nur.repos.rycee.firefox-addons.theme-nord-polar-night.addonId;
          "extensions.webextensions.ExtensionStorageIDB.migrated.${pkgs.nur.repos.rycee.firefox-addons.keepassxc-browser.addonId}" = true;

          # For TST userChrome CSS
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true; # Enable userChrome and userContent
          "layout.css.has-selector.enabled" = true; # For conditionally hiding tabs

          "extensions.pocket.enabled" = false;

          "browser.newtabpage.activity-stream.showSponsored" = false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;

          "privacy.trackingprotection.enabled" = true;
          "privacy.trackingprotection.emailtracking.enabled" = true;
          "privacy.trackingprotection.socialtracking.enabled" = true;
        };

        userChrome = ''
          /* Hide horizontal tabs at top of the window when TST visible */
          html#main-window body:has(#sidebar-box[sidebarcommand=treestyletab_piro_sakura_ne_jp-sidebar-action][checked=true]) #TabsToolbar {
            visibility: collapse !important;
          }
        '';
        # userContent = "";
      };
      
    };
  };
}
