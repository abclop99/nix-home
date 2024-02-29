{ config, pkgs, ... }: {

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
		];
	
		# Hyprland itself
		wayland.windowManager.hyprland = {
			enable = true;
			settings = {

				general = {
					gaps_in = 5;
					gaps_out = 20;
				};
				
				decoration = {
					rounding = 5;

					blur = {
						enabled = true;
						size = 3;
						passes = 1;

						vibrancy = 0.1696;
					};

					drop_shadow = true;
					shadow_range = 4;
					shadow_render_power = 3;
					"col.shadow" = "rgba(1a1a1aee)";
				};

				misc = {
					# Disable hypr-chan
					force_default_wallpaper = 0;
					# Variable refresh rate
					vrr = 1;
				};

				# Define programs to use
				"$bar" = "eww open bar";
				# "$browser" = "firefox";
				"$terminal" = "kitty";
				"$menu" = "pkill wofi; wofi --show drun";
				"$lock" = "swaylock";
				"$notif" = "swaync";

				# Execute programs at launch
				"exec-once" = [
					"$bar"
					"nm-applet --indicator"
					"$notif"
				];

				# Input config
				input = {
					kb_layout = "us,apl";
					kb_variant = "norman,";
					kb_options = "eurosign:e, caps:escape, grp:switch";

					touchpad = {
						natural_scroll = true;
					};
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
					# Fullscreen and Fullscreener
					"$mod, F, fullscreen, 1"
					"$mod SHIFT, F, fullscreen, 0"
					# Floating
					"$mod SHIFT, SPACE, togglefloating"
					# Toggle tabs
					"$mod, T, togglegroup"
					# Focus and move between tabs using < >
					"$mod, code:59, changegroupactive, b"
					"$mod, code:60, changegroupactive, f"
					"$mod SHIFT, code:59, movegroupwindow, b"
					"$mod SHIFT, code:60, movegroupwindow, f"

					# Move focus using mod + arrow keys
					"$mod, left, movefocus, l"
					"$mod, up, movefocus, u"
					"$mod, down, movefocus, d"
					"$mod, right, movefocus, r"
					# hjkl -> ynio on norman layout
					"$mod, y, movefocus, l"
					"$mod, n, movefocus, u"
					"$mod, i, movefocus, d"
					"$mod, o, movefocus, r"

					# Move windows using mod + arrow keys
					"$mod SHIFT, left, movewindow, l"
					"$mod SHIFT, up, movewindow, u"
					"$mod SHIFT, down, movewindow, d"
					"$mod SHIFT, right, movewindow, r"
					"$mod SHIFT, y, movewindow, l"
					"$mod SHIFT, n, movewindow, u"
					"$mod SHIFT, i, movewindow, d"
					"$mod SHIFT, o, movewindow, r"

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
				);

				# Move/resize mouse with mod + LMB/RMB and dragging
				bindm = [
					"$mod, mouse:272, movewindow"
					"$mod, mouse:273, resizewindow"
					"$mod ALT, mouse:272, resizewindow"
				];
				
			};
		};

		# Cursors
		home.pointerCursor = {
			gtk.enable = true;
			x11.enable = true;
			name = "breeze_cursors";
			size = 16;
			package = pkgs.libsForQt5.breeze-gtk;
		};

		# Theme
		gtk = {
			enable = true;
			theme = {
				name = "Nordic";
				package = pkgs.nordic;
			};
		};
		qt = {
			enable = true;
			platformTheme = "gtk";
		};
	
		# Menu program
		programs.wofi.enable = true;
	
		# Bar program
		programs.eww = {
			enable = true;
			configDir = ./files/eww;
			package = pkgs.eww-wayland;
		};

		# Lock screen program
		programs.swaylock = {
			enable = true;
			package = pkgs.swaylock-effects;
			settings = {
				# Behavior
				ignore-empty-password = true;
				show-failed-attempts = true;
				grace=1;
				
				# Appearance
				indicator-idle-visible = true;
				clock = true;
				fade-in = 1;
				color = "331100";

				# TODO: Swaylock effects order mattes, nix doesn't allow multiple or different orders
				screenshots = true;
				# effect-scale = 0.5;
				effect-vignette = "0.22:0.85";
				effect-custom = "${config.xdg.configHome}/swaylock/effect-blue-filter/filter.c";
				effect-blur = "7x5";
				# effect-scale = 2.0;
			};
		};
		## Needs pam access in system config for unlocking
		# Otherwise, it will not unlock
		# security.pam.services.swaylock = {};
		## Swaylock blue filter files
		xdg.configFile."swaylock/effect-blue-filter".source =
			./files/swaylock/effect-blue-filter;

		# Swayidle
		services.swayidle =
		let 
			lockProcess = "swaylock";
			lockCommand = "${pkgs.swaylock-effects}/bin/swaylock -f";
			dpmsCommand = "${pkgs.hyprland}/bin/hyprctl dispatch dpms";
		in
		{
			enable = true;
			systemdTarget = "hyprland-session.target"; # Uses hyprctl
			timeouts = [
				# Main locking timeout
				{ timeout = 600; command = lockCommand; }
				# Timeout after locked: turn off screen
				{
					timeout = 15;
					command = "if ${pkgs.procps}/bin/pgrep -x ${lockProcess}; then ${dpmsCommand} off; fi";
					resumeCommand = "${dpmsCommand} on";
				}
			];
			events = [
				{ event = "before-sleep"; command =  lockCommand; }
				{ event = "lock"; command =  lockCommand; }
			];
		};
	};
}
