{ pkgs, ... }:

{
  config = {
    # Firefox
    programs.firefox = {
      enable = true;
      # 26.05 moved configPath to XDG; pin the pre-26.05 path to keep the existing profile.
      configPath = ".mozilla/firefox";
      # TODO: profile settings, such as userchrome, extensions, etc.

      profiles.default = {
        isDefault = true;

        extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
          # Basic UI
          multi-account-containers
          # tree-style-tab

          # TST add-ons
          copy-selected-tabs-to-clipboard
          move-unloaded-tabs-for-tst
          multiple-tab-handler
          tst-indent-line
          tst-lock-tree-collapsed
          tst-more-tree-commands
          tst-wheel-and-double

          # Theme
          theme-nord-polar-night

          # Privacy
          adnauseam
          decentraleyes
          facebook-container
          libredirect
          noscript
          privacy-badger
          temporary-containers

          # QOL
          auto-tab-discard
          darkreader
          dearrow
          qr-code-address-bar
          sponsorblock
          tridactyl        # Vim-like interface for Firefox
          ublacklist
          unpaywall
          user-agent-string-switcher

          # Customization
          violentmonkey

          # Integration
          keepassxc-browser
        ];

        search = {
          default = "bing";
          privateDefault = "ecosia";
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
              icon = "https://nixos.wiki/favicon.png";
              updateInterval = 24 * 60 * 60 * 1000; # Every day
              definedAliases = [ "@nw" ];
            };

            "MyNixOS" = {
              urls = [{ template = "https://mynixos.com/search?search={searchTerms}"; }];
              icon = "https://mynixos.com/static/icons/nix-snowflake-white.svg";
              updateInterval = 24 * 60 * 60 * 1000; # Every day
              definedAliases = [ "@mynixos" ];
            };

            "Arch Wiki" = {
              urls = [{ template = "https://wiki.archlinux.org/index.php?search={searchTerms}"; }];
              icon = "https://wiki.archlinux.org/favicon.ico";
              updateInterval = 24 * 60 * 60 * 1000; # Every day
              definedAliases = [ "@aw" ];
            };

            "Lib.rs" = {
              urls = [{ template = "https://lib.rs/search?q={searchTerms}"; }];
              icon = "https://lib.rs/favicon.ico";
              updateInterval = 24 * 60 * 60 * 1000; # Every day
              definedAliases = [ "@rs" ];
            };

            ecosia = {
              urls = [{ template = "https://www.ecosia.org/search?q={searchTerms}"; }];
              icon = "https://www.ecosia.org/static/icons/favicon.ico";
              updateInterval = 24 * 60 * 60 * 1000; # Every day
              definedAliases = [ "@e" "@ecosia" ];
            };

            bing.metaData.alias = "@b";
            google.metaData.alias = "@g";
          };
        };

        settings = {
          # Extensions
          "extensions.activeThemeID" = pkgs.nur.repos.rycee.firefox-addons.theme-nord-polar-night.addonId;
          "extensions.webextensions.ExtensionStorageIDB.migrated.${pkgs.nur.repos.rycee.firefox-addons.keepassxc-browser.addonId}" = true;

          # For TST userChrome CSS
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true; # Enable userChrome and userContent
          "layout.css.has-selector.enabled" = true; # For conditionally hiding tabs

          # Customization
          "browser.theme.content-theme" = 0; # Why doesn't this apply?
          "browser.theme.toolbar-theme" = 0;
          "browser.toolbars.bookmarks.visibility" = "newtab";
          # No annoying sponsored/Pocket stuff
          "extensions.pocket.enabled" = false;
          "browser.newtabpage.activity-stream.showSponsored" = false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;

          # Route file dialogs through xdg-desktop-portal instead of Firefox's
          # in-process GTK3 chooser, which ABORTS the whole browser here: the
          # GTK chooser opens org.gtk.Settings.FileChooser via GSettings, that
          # schema is absent from this session's XDG_DATA_DIRS (`gsettings
          # list-schemas` → "No schemas installed" — nixpkgs' firefox wrapper
          # adds only adwaita-icon-theme, and gtk3 ships its schemas under
          # share/gsettings-schemas/<name>/, which nothing puts on the session
          # path), and a missing schema is a fatal g_error() → abort. With
          # `browser.download.useDownloadDir = false` (always ask where to
          # save) that fired on every single download. The portal's chooser
          # runs out-of-process in xdg-desktop-portal-gtk, which IS wrapped
          # with its own gtk3 schemas, so it resolves fine. 1 = always.
          "widget.use-xdg-desktop-portal.file-picker" = 1;

          # Tracking protection
          "privacy.trackingprotection.enabled" = true;
          "privacy.trackingprotection.emailtracking.enabled" = true;
          "privacy.trackingprotection.socialtracking.enabled" = true;

          # Let Mozilla's f1tv webcompat intervention run despite RFP
          "privacy.resistFingerprinting.exemptedDomains" =
            "f1tv.formula1.com,account.formula1.com,login.formula1.com,formula1.com";
        };

        userChrome = ''
          /*
          Hide horizontal tabs at top of the window when TST visible
          https://github.com/piroor/treestyletab/wiki/Code-snippets-for-custom-style-rules#hide-horizontal-tabs-at-the-top-of-the-window-1349-1672-2147
          */
          html#main-window body:has(#sidebar-box[sidebarcommand=treestyletab_piro_sakura_ne_jp-sidebar-action][checked=true]) #TabsToolbar {
            visibility: collapse !important;
          }

          /*
          Auto show/hide theme
          Requires additional CSS in TST addon preferences
          https://github.com/piroor/treestyletab/wiki/Code-snippets-for-custom-style-rules#full-auto-showhide-theme
          */

          /* Hide main tabs toolbar */
          #main-window[tabsintitlebar="true"]:not([extradragspace="true"]) #TabsToolbar > .toolbar-items {
            opacity: 0;
            pointer-events: none;
          }
          #main-window:not([tabsintitlebar="true"]) #TabsToolbar {
            visibility: collapse !important;
          }

          /* Sidebar min and max width removal */
          #sidebar-box {
            max-width: none !important;
            min-width: 0px !important;
          }
          /* Hide splitter, when using Tree Style Tab. */
          #sidebar-box[sidebarcommand="treestyletab_piro_sakura_ne_jp-sidebar-action"] + #sidebar-splitter {
            display: none !important;
          }
          /* Hide sidebar header, when using Tree Style Tab. */
          #sidebar-box[sidebarcommand="treestyletab_piro_sakura_ne_jp-sidebar-action"] #sidebar-header {
            visibility: collapse;
          }

          /* Shrink sidebar until hovered, when using Tree Style Tab. */
          :root {
            --thin-tab-width: 4rem;
            --wide-tab-width: 25rem;
          }
          #sidebar-box:not([sidebarcommand="treestyletab_piro_sakura_ne_jp-sidebar-action"]) {
            min-width: var(--wide-tab-width) !important;
            max-width: none !important;
          }
          #sidebar-box[sidebarcommand="treestyletab_piro_sakura_ne_jp-sidebar-action"] {
            position: relative !important;
            transition: all 100ms !important;
            min-width: var(--thin-tab-width) !important;
            max-width: var(--thin-tab-width) !important;

            /* Dynamically compute z-index to be in front */
            z-index: calc(var(--browser-area-z-index-tabbox) + 1);
          }
          #sidebar-box[sidebarcommand="treestyletab_piro_sakura_ne_jp-sidebar-action"]:hover {
            transition: all 200ms !important;
            transition-delay: 0.2s !important;
            min-width: var(--wide-tab-width) !important;
            max-width: var(--wide-tab-width) !important;
            margin-right: calc((var(--wide-tab-width) - var(--thin-tab-width)) * -1) !important;
          }
        '';
        # userContent = "";
      };
      
    };
  };
}
