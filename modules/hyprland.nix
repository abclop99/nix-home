{ config, lib, pkgs, ... }:
let
	# Host-specific extra Hyprland binds live in a skip-worktree'd private file
	# (empty-list placeholder in git, real binds on disk). See private/hyprland.nix
	# and CLAUDE.md. Empty on machines with no host-specific binds → no-op.
	private = import ../private/hyprland.nix;

	# GSettings schema dirs to hand the session; see the GSETTINGS_SCHEMA_DIR env
	# entry below for why. nixpkgs installs these under share/gsettings-schemas/
	# <name>/, one level deeper than the share/glib-2.0/schemas that GLib scans.
	schemaDirs = lib.concatMapStringsSep ":"
		(p: "${p}/share/gsettings-schemas/${p.name}/glib-2.0/schemas")
		[ pkgs.gsettings-desktop-schemas pkgs.gtk3 ];
in {

	config = {

		# Other packages
		home.packages = with pkgs; [
			networkmanagerapplet    # Systray for NetworkManager
			grimblast               # Screenshot tool for hyprland
			swaynotificationcenter  # Notification center
			
			# Used in eww's scripts
			# TODO: Wrap dependencies in the scripts?
			jaq
			socat
			python3
			pamixer                 # Volume info and control
			pulseaudio              # pactl subscribe
			brightnessctl           # Brightness control
			bemenu                  # Menu program (launcher)
		];

		programs = {
			bemenu = {
				enable = true;
			};
		};
	
		# Hyprland itself
		wayland.windowManager.hyprland = {
			enable = true;
			# 26.05 changed the default to "lua"; pin hyprlang to keep our config language.
			configType = "hyprlang";
			xwayland.enable = true;

			plugins = with pkgs; [
				# i3/sway like layout
				hyprlandPlugins.hy3
			];

			settings = {

				env = [
          # "LIBVA_DRIVER_NAME,nvidia"
          # "XDG_SESSION_TYPE,wayland"
          # WLR_NO_HARDWARE_CURSORS was set here and did nothing: Hyprland
          # dropped wlroots at 0.42, and this closure holds no wlroots
          # derivation at all, so nothing could ever have read it. Software
          # cursors are in force regardless, via `cursor:no_hardware_cursors`
          # at its default of Auto — CLAUDE.md carries the mechanism, and what
          # forcing it to 0 would and would not settle.
          "HYPRCURSOR_THEME,rose-pine-hyprcursor"
          "HYPRCURSOR_SIZE,24"
          # GTK derives its Xft DPI from the org.gnome.desktop.interface
          # GSettings schema (text-scaling-factor). That schema ships in
          # gsettings-desktop-schemas, which is on NO XDG_DATA_DIRS entry here
          # (neither /run/current-system/sw nor the HM profile expose a
          # share/glib-2.0/schemas), so GTK never sets xft-dpi and
          # gdk_screen_get_resolution() keeps its "unset" sentinel of -1.
          # Firefox converts the system font's *point* size to pixels with
          # `pt * dpi / 72`, so a -1 DPI yields a NEGATIVE font size (10pt ->
          # -0.138889px) and every chrome label — tab titles, URL bar, menus —
          # renders as nothing. Page content is unaffected (CSS px), as are
          # icons, which is why the browser otherwise looks fine.
          #
          # gtk3's own schema dir is listed alongside it because
          # org.gtk.Settings.FileChooser lives there, NOT in
          # gsettings-desktop-schemas — and a missing schema is a fatal
          # g_error(), so GTK3's in-process file chooser aborts the whole
          # app rather than degrading. That is what crashed Firefox on every
          # download; see modules/firefox.nix. Apps wrapped by wrapGAppsHook
          # (chromium, xdg-desktop-portal-gtk) carry their own copies and were
          # never affected, which is what made this look Firefox-specific.
          #
          # GSETTINGS_SCHEMA_DIR is colon-separated and additive (searched
          # alongside XDG_DATA_DIRS), so this only adds the missing schemas
          # without hiding any other app's.
          "GSETTINGS_SCHEMA_DIR,${schemaDirs}"
        ];

				monitor = [
					# Laptop display
					"eDP-1, preferred, 0x0, 1.2" # 1920 / 1.2 = 1600
					"desc:LG Electronics LG FHD 0x01010101, preferred, 1600x-360, 1.0"
					# Xiaomi Mi Monitor, on the mini-DisplayPort. 3840 / 1.5 = 2560 and
					# 2160 / 1.5 = 1440, so the logical size is the same 2560x1440 this
					# ran at before — only the pixel density changes. y = 900 - 1440 =
					# -540 bottom-aligns it with the laptop (eDP-1 is 1920x1080 at scale
					# 1.2 -> 1600x900 logical, at 0x0).
					#
					# The mode is spelled out rather than left as `preferred` for
					# explicitness, not because the two differ here: a scale of 1.5
					# only means something against a known 3840x2160, and on this
					# connector both forms pick the same mode. (CLAUDE.md covers how
					# to check which mode an EDID prefers, and what actually makes
					# the obvious way work.)
					#
					# This rule is keyed by `desc:`, so it follows the monitor onto
					# ANY connector — but the mode is now the port-dependent half,
					# and that is a real loss against the 2560x1440@59.95 it
					# replaced, which both connectors offered. The dump from the
					# previous one (DP-4) had no 4K@60 at all, and Hyprland matches
					# nearest with resolution ranked above refresh, so there this
					# would settle on 4K@29.97 rather than fall back to 1440p@60 —
					# silently, because a mode miss raises no config error and the
					# DEBUG line that would say so is suppressed by the default
					# `debug:disable_logs`. The blast radius is refresh, NOT layout:
					# 3840/1.5 is still 2560, so the logical size and the -540
					# alignment above both survive and all you lose is 60 Hz.
					# Re-check the mode if it ever moves ports.
					#
					# Deliberately NOT asserted: why the two connectors advertised
					# different modes. It is not a plain link ceiling — a narrower
					# link can only prune, yet DP-4 offered 4K@25 and 4K@23.98 that
					# DP-3 does not, so the lists are not nested and the sink's own
					# EDID must have differed. Which physical socket DP-4 is was
					# never determined either.
					"desc:Xiaomi Corporation Mi Monitor 6732000000074, 3840x2160@60, 1600x-540, 1.5"
					# Default, any random monitor connected. Automatically placed to the right
					",preferred,auto,1"
				];

				general = {
					gaps_in = 5;
					gaps_out = 20;

					# Enable hy3 layout
					layout = "hy3";
				};
				
				decoration = {
					rounding = 5;

					blur = {
						enabled = true;
						size = 3;
						passes = 1;

						vibrancy = 0.1696;
					};

					# drop_shadow = true;
					# shadow_range = 4;
					# shadow_render_power = 3;
					# "col.shadow" = "rgba(1a1a1aee)";
				};

				misc = {
					# Disable hypr-chan
					force_default_wallpaper = 0;
					# Variable refresh rate
					vrr = 1;
				};

				# Define programs to use
				# The bar is not here: it runs as the eww-daemon and eww-bars user
				# units below.
				# "$browser" = "firefox";
				"$terminal" = "${pkgs.kitty}/bin/kitty";
				"$menu" = "${pkgs.bemenu}/bin/bemenu-run";
				"$lock" = "${pkgs.systemd}/bin/loginctl lock-session";
				"$notif" = "${pkgs.swaynotificationcenter}/bin/swaync";

				# Execute programs at launch
				"exec-once" = [
					"$notif"

					# Systray items
					"${pkgs.keepassxc}/bin/keepassc"
					"${pkgs.networkmanagerapplet}/bin/nm-applet --indicator"
					"${pkgs.systemd}/bin/systemctl --user start blueman-applet.service"
					"${pkgs.antimicrox}/bin/antimicrox --tray"
				];

				exec = [
					"${pkgs.hyprshade}/bin/hyprshade auto"
				];

				# Input config
				input = {
					# Keyboard layout
					kb_layout = "us,apl";
					kb_variant = "norman,";
					kb_options = "eurosign:e, caps:escape, grp:switch";

					# Enable numlock by default
					numlock_by_default = true;

					# Touchpad scroll direction
					touchpad = {
						natural_scroll = true;
					};

					# Fix menus closing immediately
					# mouse_refocus=false;
				};

				# Super (win) key for modifier
				"$mod" = "SUPER";

				# Binds
				# Super key on its own -> menu
				# bindr = "SUPER, SUPER_L, exec, $menu";
				bind = [
					# Keybinds for launching stuff
					"$mod, SPACE, exec, $menu"
					"$mod, RETURN, exec, $terminal"
					", Print, exec, grimblast copy area"
					"$mod, L, exec, $lock"

					## Keybinds for window managment
					# Close window
					"$mod SHIFT, Q, killactive"
					# Toggle fullscreen
					"$mod, F, fullscreen, 0"
					# Toggle floating
					"$mod SHIFT, SPACE, togglefloating"
					## Splitting containers
					# Split opposite
					"$mod, V, hy3:makegroup, opposite, ephemeral"
					## Changing container layout
					# Toggle tabs
					"$mod, W, hy3:changegroup, toggletab"
					# Switch between vertical/horizontal (if untabbed)
					"$mod, E, hy3:changegroup, opposite"

					# Raise/lower focus
					"$mod, a, hy3:changefocus, raise"
					"$mod SHIFT, a, hy3:changefocus, lower"

					# Move focus using mod + arrow keys
					"$mod, left, hy3:movefocus, l"
					"$mod, up, hy3:movefocus, u"
					"$mod, down, hy3:movefocus, d"
					"$mod, right, hy3:movefocus, r"
					# hjkl -> ynio on norman layout
					# jkl; -> nioh on Norman layout
					"$mod, n, hy3:movefocus, l"
					"$mod, i, hy3:movefocus, d"
					"$mod, o, hy3:movefocus, u"
					"$mod, h, hy3:movefocus, r"

					# Move windows using mod + arrow keys
					# Will move windows in/out of groups
					"$mod SHIFT, left, movewindoworgroup, l"
					"$mod SHIFT, up, movewindoworgroup, u"
					"$mod SHIFT, down, movewindoworgroup, d"
					"$mod SHIFT, right, movewindoworgroup, r"
					"$mod SHIFT, n, movewindoworgroup, l"
					"$mod SHIFT, i, movewindoworgroup, d"
					"$mod SHIFT, o, movewindoworgroup, u"
					"$mod SHIFT, h, movewindoworgroup, r"

					# Move windows or full groups using mod + arrow keys
					"$mod CTRL SHIFT, left, hy3:movewindow, l"
					"$mod CTRL SHIFT, up, hy3:movewindow, u"
					"$mod CTRL SHIFT, down, hy3:movewindow, d"
					"$mod CTRL SHIFT, right, hy3:movewindow, r"
					"$mod CTRL SHIFT, n, hy3:movewindow, l"
					"$mod CTRL SHIFT, i, hy3:movewindow, d"
					"$mod CTRL SHIFT, o, hy3:movewindow, u"
					"$mod CTRL SHIFT, h, hy3:movewindow, r"

					# Move workspaces between monitors
					"$mod CTRL, left, movecurrentworkspacetomonitor, l"
					"$mod CTRL, up, movecurrentworkspacetomonitor, u"
					"$mod CTRL, down, movecurrentworkspacetomonitor, d"
					"$mod CTRL, right, movecurrentworkspacetomonitor, r"
					"$mod CTRL, n, movecurrentworkspacetomonitor, l"
					"$mod CTRL, i, movecurrentworkspacetomonitor, d"
					"$mod CTRL, o, movecurrentworkspacetomonitor, u"
					"$mod CTRL, h, movecurrentworkspacetomonitor, r"

					# Special workspace (scratchpad)
					# TODO: What does this do?
					"$mod, S, togglespecialworkspace, magic"
					"$mod SHIFT, S, togglespecialworkspace, special:magic"
				]
				++ (
					# workspaces Shortcuts
					# binds $mod + [shift +] {1..10} to [move to] workspace {1..10}
					builtins.concatLists (builtins.genList (
						x: let
							ws = let
								c = (x + 1) / 10;
							in
								builtins.toString (x + 1 - (c * 10));
						in [
							"$mod, ${ws}, workspace, ${toString (x + 1)}"
							"$mod SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
						]
					) 10)
				)
				++ private.extraBinds;

				# Media key binds
				bindel = [
					", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
					", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
				];
				bindl = [
					", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
					", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
				];

				# Move/resize mouse with mod + LMB/RMB and dragging
				bindm = [
					"$mod, mouse:272, movewindow"
					"$mod, mouse:273, resizewindow"
					"$mod SHIFT, mouse:272, resizewindow"
				];

				# Window rules
				windowrule = [
					# Add slight transparency to non-fullscreen windows
					"match:fullscreen 0, opacity 0.95"

					# Inhibit idle when fullscreen
					"match:fullscreen 1, idle_inhibit fullscreen"
					
					# Floating, pinned, small in corner Picure-in-Picture window
					"match:class firefox, match:title Picture-in-Picture, float true"
					"match:class firefox, match:title Picture-in-Picture, pin true"
					"match:class firefox, match:title Picture-in-Picture, size 240 135"
					"match:class firefox, match:title Picture-in-Picture, move 990 550"
					# Make slightly transparent when not fullscreen
					"match:class firefox, match:title Picture-in-Picture, match:fullscreen 0, opacity 0.9"
					# TODO: Allow fullscreen for P-i-P

					# Fix menus closing in a few applications
					"match:title ^()$, match:class ^(steam)$, stay_focused true"
					"match:title ^()$, match:class ^(zoom)$, stay_focused true"
				];
				
			};
		};

		# Cursors
		# XCursor: real Breeze (used by XWayland clients and anything querying XCursor).
		# Hyprcursor: rose-pine-hyprcursor — wired up below via Hyprland env + the
		# xdg.dataFile symlink so libhyprcursor finds it. (No hyprcursor-format
		# Breeze exists; rose-pine cursors are Breeze-derived and visually similar.)
		home.pointerCursor = {
			gtk.enable = true;
			x11.enable = true;
			name = "breeze_cursors";
			size = 24;
			package = pkgs.kdePackages.breeze;
		};

		# home.pointerCursor only manages one theme, so expose the hyprcursor theme
		# manually on the standard ~/.local/share/icons search path.
		xdg.dataFile."icons/rose-pine-hyprcursor".source =
			"${pkgs.rose-pine-hyprcursor}/share/icons/rose-pine-hyprcursor";

		# Theme (GTK theme + dconf color-scheme live in modules/theme.nix)
		qt = {
			enable = true;
			platformTheme.name = "gtk";
		};

		# Hyprshade configuration
		xdg.configFile."hypr/hyprshade.toml".text = ''
[[shades]]
name = "blue-light-filter"
start_time = 21:00:00
end_time = 07:00:00
		'';
		# Systemd service unit
		systemd.user.services.hyprshade = {
			Unit = {
				Description = "Apply screen filter";
			};
			Service = {
				Type = "oneshot";
				ExecStart = "${pkgs.hyprshade}/bin/hyprshade auto";
			};
		};
		# Systemd timer unit
		systemd.user.timers.hyprshade = {
			Unit = {
				Description = "Apply screen filter on a schedule";
			};
			Timer = {
				OnCalendar = [
					"21:00:00"
					"07:00:00"
				];
			};
			Install.WantedBy = [ "timers.target" ];
		};

		# Polkit authentication agent. Replicates the unit shipped at
		# ${pkgs.hyprpolkitagent}/share/systemd/user/hyprpolkitagent.service
		# so HM owns the install link instead of relying on the package's.
		systemd.user.services.hyprpolkitagent = {
			Unit = {
				Description = "Hyprland Polkit Authentication Agent";
				PartOf = [ "graphical-session.target" ];
				After = [ "graphical-session.target" ];
				ConditionEnvironment = "WAYLAND_DISPLAY";
			};
			Service = {
				ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
				Slice = "session.slice";
				TimeoutStopSec = "5sec";
				Restart = "on-failure";
			};
			Install.WantedBy = [ "graphical-session.target" ];
		};

		# eww's daemon, supervised. It used to start as a side effect of the first
		# `eww open` in sync-bars, which left nothing watching it: this unit's Main
		# PID was the script, so systemd saw a healthy unit while a dead daemon
		# took every bar with it, and nothing recovered until the next hotplug.
		# The worse half is that `eww open` starts a daemon whenever it cannot
		# *reach* one, so a daemon that was merely busy got a second forked
		# alongside it -- the newcomer rebound the socket and the original kept
		# drawing a full set of bars that `eww active-windows` could no longer see
		# or close, which is how every monitor ended up with two. Owning the
		# lifetime here settles "is the daemon alive" by process supervision
		# instead of over the very IPC that had broken, and lets sync-bars refuse to
		# start one at all -- it passes --no-daemonize, which is only safe because
		# this unit guarantees the daemon exists.
		#
		# This is the unit to restart for a full config reload -- a daemon holds
		# its config parsed in memory, and systemd's default KillMode of
		# control-group takes it down along with the listeners it spawned.
		# eww-bars is PartOf it, so it comes too and reopens the bars.
		#
		# RestartSec=5, with StartLimitIntervalSec=0 behind it. `eww daemon` exits 1
		# in ~40ms with "Failed to initialize GTK" whenever the compositor is not
		# reachable -- a logout race, or a cold boot this unit wins -- and at 2s
		# spacing a run of that walks into the default burst of 5 per 10s, which
		# latches the unit `failed` for the rest of the session with nothing to
		# restart it. ConditionEnvironment is no help: HYPRLAND_INSTANCE_SIGNATURE
		# outlives Hyprland in the user manager's environment, so the condition
		# still passes.
		#
		# At 5s the count cannot reach the burst before the 10s window resets, so
		# the limit is already out of reach and StartLimitIntervalSec=0 is a
		# backstop rather than the thing doing the work -- kept so that lowering
		# RestartSec later cannot quietly restore a session-long silent latch. It
		# is not free: a *propagated* restart bypasses RestartSec entirely, and with
		# the limit switched off nothing else brakes such a loop -- a synthetic
		# reproduction of that shape spins at ~33ms per cycle. What keeps sync-bars
		# off it is the 10-13s its retries take before it asks for a restart.
		#
		# PATH is deliberately inherited from the user manager (which carries the
		# HM profile) rather than pinned. eww launches its own deflisten commands
		# as `bash ./scripts/...`, and those scripts reach for brightnessctl,
		# pamixer, pactl, python, jaq, socat and friends — pinning PATH would mean
		# enumerating every one and keeping the list in sync, silently breaking a
		# widget as soon as one is added.
		systemd.user.services.eww-daemon = {
			Unit = {
				Description = "eww widget daemon";
				PartOf = [ "graphical-session.target" ];
				After = [ "graphical-session.target" ];
				ConditionEnvironment = "HYPRLAND_INSTANCE_SIGNATURE";
				StartLimitIntervalSec = 0;
				# Pull the bars up alongside the daemon. Every other edge between these
				# two points bars -> daemon, so nothing propagates a *start* downward:
				# `systemctl stop eww-daemon` leaves eww-bars `inactive` with
				# Result=success -- invisible to `systemctl --failed` -- and a later
				# `start eww-daemon` would not bring it back. `restart` was always fine;
				# it is stop-then-start that stranded it.
				Wants = [ "eww-bars.service" ];
			};
			Service = {
				# Kill any daemon this unit doesn't own before starting. A daemon
				# holds its config parsed in memory, so one left over from a
				# previous generation (or from the pre-unit exec-once) would serve
				# the *old* widget tree. `-` because there is nothing to kill on a
				# fresh login. This only reaches strays that still answer IPC --
				# against a wedged one it fails and `eww daemon` rebinds the socket
				# over the top, orphaning it, so this is a courtesy rather than a
				# guarantee; for the unit's own daemon the cgroup teardown does it.
				ExecStartPre = "-${pkgs.eww}/bin/eww kill";
				ExecStart = "${pkgs.eww}/bin/eww daemon --no-daemonize";
				Slice = "session.slice";
				Restart = "always";
				RestartSec = 5;
			};
			Install.WantedBy = [ "graphical-session.target" ];
		};

		# One eww bar per connected monitor, re-synced on hotplug. A user unit
		# rather than an exec-once so it restarts on failure and stops cleanly on
		# logout.
		#
		# Hyprland's first exec-once hands HYPRLAND_INSTANCE_SIGNATURE to the
		# systemd user environment via dbus-update-activation-environment before
		# it starts the session target, so the script's socket2 path resolves.
		systemd.user.services.eww-bars = {
			Unit = {
				Description = "Open an eww bar on each connected monitor";
				# A fresh daemon has no windows open, so the bars have to be
				# reopened against it. PartOf propagates a *restart* and not merely
				# a stop, which is what makes that automatic -- verified on systemd
				# 260 with transient units: SIGKILLing the depended-on unit's main
				# process gave the dependent a new InvocationID at NRestarts=0, so
				# the restart was job-driven and not its own Restart=. After only
				# orders the start and settles nothing here.
				#
				# Requires= is deliberately absent. Isolated the same way, it turns
				# out to propagate an auto-restart just as PartOf does, so it adds no
				# reach -- but it does add a failure mode: when the daemon exhausts a
				# start limit, a Requires= dependent's start job is refused and it
				# lands `inactive` with Result=success, absent from `systemctl
				# --failed` and looking like a clean exit. Its immediate start job
				# also bypasses RestartSec and spends one of the daemon's tries.
				PartOf = [ "graphical-session.target" "eww-daemon.service" ];
				After = [ "graphical-session.target" "eww-daemon.service" ];
				ConditionEnvironment = "HYPRLAND_INSTANCE_SIGNATURE";
				# As on the daemon, and a backstop for the same reason once RestartSec
				# matches. Latching `failed` would be the worse failure here: a broken
				# widget tree fails every start, and nothing would recover it, because
				# fixing the yuck changes no unit text for sd-switch to act on. Looping
				# in the journal is visible and self-clearing instead -- eww's filewatch
				# reloads the daemon, and the next restart of this unit then succeeds.
				StartLimitIntervalSec = 0;
				# The gap this closes is sync-bars, not the listeners. Every file in
				# ~/.config/eww is a symlink into one aggregate home-manager-files
				# derivation, so a scripts-only edit repoints eww.scss and the yuck as
				# well; eww's filewatch only matches paths ending .yuck/.scss/.css, so
				# that repoint is precisely what trips it, and a reload calls stop_all()
				# on the script vars before re-initialising, respawning every deflisten
				# child. Verified with a comment-only script edit whose rendered scss and
				# yuck were byte-identical: every listener took a new PID while the
				# daemon kept its own.
				# sync-bars is this unit's ExecStart rather than something eww launches,
				# so no reload can touch it -- it held one PID across every such switch.
				# Since the split this restart no longer reaches the daemon, so a changed
				# *listener* script is picked up only by eww's filewatch above; this
				# trigger covers sync-bars itself. Before it, the restart went through
				# ExecStartPre=-eww kill and this cgroup and forced a re-parse too.
				# Naming the scripts path here covers it, and makes the restart
				# guaranteed rather than a side effect of how HM bundles files.
				# sd-switch acts because the field is not on its ignore list: Description
				# and Documentation are ignored, every other key is significant whether
				# X-prefixed or not. X-Reload-Triggers would be actively wrong -- it
				# selects the reload path, and this unit is CanReload=no.
				# Tracked files only: an untracked new script neither deploys nor
				# triggers, and is not even reported dirty. Scripts only, deliberately --
				# the scss is generated per specialisation, so including it would fire
				# this on every darkman transition.
				X-Restart-Triggers = [ "${config.xdg.configFile."eww/scripts".source}" ];
			};
			Service = {
				ExecStart = "${pkgs.bash}/bin/bash ${config.xdg.configHome}/eww/scripts/sync-bars";
				Slice = "session.slice";
				# "always", not "on-failure": the script's socat tail exits 0 when
				# the Hyprland socket closes, which would otherwise leave the unit
				# inactive with nothing reconciling. It also covers the script
				# exiting 1 after the daemon stayed unreachable through every retry
				# -- re-running the whole reconcile is the recovery. At real session
				# end PartOf stops the unit, and a stop is not a restart trigger.
				Restart = "always";
				# 5 rather than 2, matching the daemon. Not every failure path pays the
				# retry loop's 10-13s: a config that loads but has no `bar` widget
				# answers active-windows fine and fails only at `eww open`, so sync
				# returns 1 at once and this interval alone sets the retry cadence. At 2s
				# that is five starts inside ten seconds -- exactly the default burst --
				# so what the unit did next would hinge on StartLimitIntervalSec rather
				# than on this. At 5s the burst stays out of reach and that override goes
				# back to being the backstop it is described as.
				RestartSec = 5;
			};
			Install.WantedBy = [ "graphical-session.target" ];
		};

		# Bar program
		programs.eww = {
			enable = true;
			package = pkgs.eww;
			# Don't use configDir: it makes ~/.config/eww a symlink to a
			# generation-specific store path, which changes eww-server's
			# socket name on every switch and breaks `eww reload`. Use
			# per-file xdg.configFile entries so ~/.config/eww stays a
			# real directory with a stable realpath.
		};

		xdg.configFile = {
			"eww/bar.yuck".source = ../files/eww/bar.yuck;
			"eww/clock.yuck".source = ../files/eww/clock.yuck;
			"eww/controls.yuck".source = ../files/eww/controls.yuck;
			"eww/eww.yuck".source = ../files/eww/eww.yuck;
			"eww/hyprland.yuck".source = ../files/eww/hyprland.yuck;
			"eww/system.yuck".source = ../files/eww/system.yuck;
			"eww/scripts".source = ../files/eww/scripts;
			"eww/eww.scss".text =
				import ../files/eww/eww.scss.nix { inherit (config.theme) palette; };
		};

		# Lock screen program
		programs.hyprlock = {
			enable = true;

			# https://wiki.hyprland.org/Hypr-Ecosystem/hyprlock/
			settings = {
				general = {
					# 0 = manual Super+L and suspend-resume require password
					# immediately. The idle listener overrides this with
					# --grace 5 (see hypridle config below).
					grace = 0;
					ignore_empty_input = true;
				};

				# Explicit fadeIn/fadeOut. Hyprlock only registers the
				# `linear` bezier in its AnimationManager, so the global
				# default ("default") falls back to a no-op and fades warp
				# instantly. Pin fadeIn/fadeOut to `linear` so the speed
				# (deciseconds) actually applies. 10 = ~1s.
				animations = {
					enabled = true;
					animation = [
						"fadeIn, 1, 10, linear"
						"fadeOut, 1, 2, linear"
					];
				};

				background = [
					{
						monitor = "";
						path = "screenshot";

						blur_passes = 3;
						blur_size = 3;
						noise = 0.0117;
					}
				];

				shape = [
					{
						monitor = "";
				    size = "360, 60";
				    color = "rgba(17, 17, 17, 1.0)";
				    rounding = -1;
				    border_size = 8;
				    border_color = "rgba(0, 207, 230, 1.0)";
				    rotate = 0;
				    xray = false; # if true, make a "hole" in the background (rectangle of specified size, no rotation)

				    position = "0, 20";
				    halign = "center";
				    valign = "center";
					}
				];

				label = [
					{
						monitor = "";
						text = "$TIME";
						text_align = "center";
						color = "#eceff4";
					  shadow_passes = 3;
					  shadow_color="rgb(46, 52, 64, 1.0)";
						font_size = 30;

				    position = "0, 140";
				    halign = "center";
				    valign = "center";
					}
					{
				    monitor = "";
				    text = "Hi there, $USER";
				    text_align = "center"; # center/right or any value for default left. multi-line text alignment inside label container
				    color = "rgba(200, 200, 200, 1.0)";
				    font_size = 25;
				    font_family = "Noto Sans";

				    position = "0, 20";
				    halign = "center";
				    valign = "center";
					}
					{
						# Show fail reason and number of attempts under input field
				    monitor = "";
				    text = "$FAIL $ATTEMPTS[]";
				    text_align = "center"; # center/right or any value for default left. multi-line text alignment inside label container
				    color = "rgba(191, 97, 106, 1.0)";
					  shadow_passes = 3;
					  shadow_color="rgb(46, 52, 64, 1.0)";
				    font_size = 20;
				    font_family = "Noto Sans";

				    position = "0, -180";
				    halign = "center";
				    valign = "center";
					}
				];

				input-field = [
					{
						monitor = "";
				    size = "200, 50";
				    outline_thickness = 3;
				    dots_size = 0.33; # Scale of input-field height, 0.2 - 0.8
				    dots_spacing = 0.15; # Scale of dots' absolute size, 0.0 - 1.0
				    dots_center = false;
				    dots_rounding = -1; # -1 default circle, -2 follow input-field rounding
				    outer_color = "rgb(151515)";
				    inner_color = "rgb(200, 200, 200)";
				    font_color = "rgb(10, 10, 10)";
				    fade_on_empty = true;
				    fade_timeout = 1000; # Milliseconds before fade_on_empty is triggered.
				    placeholder_text = "<i>Input Password...</i>"; # Text rendered in the input box when it's empty.
				    hide_input = false;
				    rounding = -1; # -1 means complete rounding (circle/oval)
				    check_color = "rgb(204, 136, 34)";
				    fail_color = "rgb(204, 34, 34)"; # if authentication failed, changes outer_color and fail message color
				    fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>"; # can be set to empty
				    fail_transition = 300; # transition time in ms between normal outer_color and fail_color
				    capslock_color = -1;
				    numlock_color = -1;
				    bothlock_color = -1; # when both locks are active. -1 means don't change outer color (same for above)
				    invert_numlock = false; # change color if numlock is off
				    swap_font_color = false; # see below

				    position = "0, -80";
				    halign = "center";
				    valign = "center";
					}
				];
			};
		};
		## Needs pam access in system config for unlocking
		# Otherwise, it will not unlock
		# security.pam.services.swaylock = {};
		## Swaylock blue filter files
		xdg.configFile."swaylock/effect-blue-filter".source =
			../files/swaylock/effect-blue-filter;

		# Swayidle
		services.hypridle =
		let
			dpms_command = "${pkgs.hyprland}/bin/hyprctl dispatch dpms";
		in
		{
			enable = true;

			# https://wiki.hyprland.org/Hypr-Ecosystem/hypridle/
			settings = {
				general = {
					lock_cmd = "${pkgs.procps}/bin/pgrep -x hyprlock || ${pkgs.hyprlock}/bin/hyprlock"; # Avoid starting multiple hyprlock instances
					before_sleep_cmd = "loginctl lock-session"; # Lock before suspend
					after_sleep_cmd = "${dpms_command} on"; # To avoid having to press a key twice to turn on the display
				};

				# Dim the screen 30s before the lock fires (warning)
				listener = [
					{
						timeout = 270;       # 4.5 min (30s before lock at 300s)
						on-timeout = "${pkgs.brightnessctl}/bin/brightnessctl -s set 10"; # Set monitor backlight to log
						on-resume = "${pkgs.brightnessctl}/bin/brightnessctl -r";        # Restore monitor backlight
					}

					{
						timeout = 300;       # 5 min
						# Launch hyprlock directly (not via loginctl) so we can pass --grace,
						# giving 5s after the lock appears where any input dismisses it
						# without a password. Manual lock + suspend still go through
						# loginctl/lock_cmd and pick up grace=0 from the hyprlock config.
						on-timeout = "${pkgs.procps}/bin/pgrep -x hyprlock || ${pkgs.hyprlock}/bin/hyprlock --grace 5";
					}

					{
						timeout = 10;       # Seconds after last interaction
						on-timeout = "${pkgs.procps}/bin/pgrep -x hyprlock && ${dpms_command} off";  # Turn off screen if locked
						on-resume = "${dpms_command} on";  # Screen on
					}

					{
						timeout = 310;       # Seconds after lock
						on-timeout = "${pkgs.procps}/bin/pgrep -x hyprlock && ${dpms_command} off";  # Turn off screen if locked
						on-resume = "${dpms_command} on";  # Screen on
					}

					# {
					# 	timeout = 1800;      # 30 min
					# 	on-timeout = "${pkgs.systemd}/bin/systemctl suspend"; # Suspend PC
					# }
				];
			};
		};
	};
}
