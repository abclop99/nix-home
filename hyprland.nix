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
			bemenu                  # Menu program (launcher)
		];
	
		# Hyprland itself
		wayland.windowManager.hyprland = {
			enable = true;
			settings = {

				env = [
          # "LIBVA_DRIVER_NAME,nvidia"
          # "XDG_SESSION_TYPE,wayland"
          "WLR_NO_HARDWARE_CURSORS,1"
        ];

				monitor = [
					# Laptop display
					"eDP-1, preferred, 0x0, 1.2"
					"desc:LG Electronics LG FHD 0x01010101, preferred, -1920x-360, 1.0"
					# Default, any random monitor connected. Automatically placed to the right
					",preferred,auto,1"
				];

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
				"$menu" = "bemenu-run";
				"$lock" = "${pkgs.systemd}/bin/loginctl lock-session";
				"$notif" = "swaync";

				# Execute programs at launch
				"exec-once" = [
					"$bar"
					"$notif"

					# Systray items
					"keepassc"
					"nm-applet --indicator"
					"systemctl --user start blueman-applet.service"
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
					# Will move windows in/out of groups
					"$mod SHIFT, left, movewindoworgroup, l"
					"$mod SHIFT, up, movewindoworgroup, u"
					"$mod SHIFT, down, movewindoworgroup, d"
					"$mod SHIFT, right, movewindoworgroup, r"
					"$mod SHIFT, y, movewindoworgroup, l"
					"$mod SHIFT, n, movewindoworgroup, u"
					"$mod SHIFT, i, movewindoworgroup, d"
					"$mod SHIFT, o, movewindoworgroup, r"

					# Move windows or full groups using mod + arrow keys
					"$mod CTRL SHIFT, left, movewindow, l"
					"$mod CTRL SHIFT, up, movewindow, u"
					"$mod CTRL SHIFT, down, movewindow, d"
					"$mod CTRL SHIFT, right, movewindow, r"
					"$mod CTRL SHIFT, y, movewindow, l"
					"$mod CTRL SHIFT, n, movewindow, u"
					"$mod CTRL SHIFT, i, movewindow, d"
					"$mod CTRL SHIFT, o, movewindow, r"

					# Move workspaces between monitors
					"$mod CTRL, left, movecurrentworkspacetomonitor, l"
					"$mod CTRL, up, movecurrentworkspacetomonitor, u"
					"$mod CTRL, down, movecurrentworkspacetomonitor, d"
					"$mod CTRL, right, movecurrentworkspacetomonitor, r"
					"$mod CTRL, y, movecurrentworkspacetomonitor, l"
					"$mod CTRL, n, movecurrentworkspacetomonitor, u"
					"$mod CTRL, i, movecurrentworkspacetomonitor, d"
					"$mod CTRL, o, movecurrentworkspacetomonitor, r"

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
				windowrulev2 = [
					# Add slight transparency to non-fullscreen windows
					"opacity 0.95,fullscreen:0"

					# Inhibit idle when fullscreen
					"idleinhibit fullscreen,fullscreen:1"
					
					# Floating, pinned, small in corner Picure-in-Picture window
					"float,class:firefox,title:Picture-in-Picture"
					"pin,class:firefox,title:Picture-in-Picture"
					"size 240 135,class:firefox,title:Picture-in-Picture"
					"move 990 550,class:firefox,title:Picture-in-Picture"
					# Make slightly transparent when not fullscreen
					"opacity 0.9,class:firefox,title:Picture-in-Picture,fullscreen:0"
					# TODO: Allow fullscreen for P-i-P

					# Fix menus closing in a few applications
					"stayfocused, title:^()$,class:^(steam)$"
					"stayfocused, title:^()$,class:^(zoom)$"
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
			platformTheme.name = "gtk";
		};

		# Hyprshade configuration
		xdg.configFile."hypr/hyprshade.toml".text = ''
[[shades]]
name = "blue-light-filter"
start_time = 21:00:00
end_time = 06:00:00
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
					"06:00:00"
				];
			};
			Install.WantedBy = [ "timers.target" ];
		};
	
		# Bar program
		programs.eww = {
			enable = true;
			configDir = ./files/eww;
			package = pkgs.eww;
		};

		# Lock screen program
		programs.hyprlock = {
			enable = true;

			# https://wiki.hyprland.org/Hypr-Ecosystem/hyprlock/
			settings = {
				general = {
					grace = 2;
					ignore_empty_input = true;
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

				    position = "0, 80";
				    halign = "center";
				    valign = "center";
					}
				];

				label = [
					{
						    monitor = "";
						    text = "Hi there, $USER";
						    text_align = "center"; # center/right or any value for default left. multi-line text alignment inside label container
						    color = "rgba(200, 200, 200, 1.0)";
						    font_size = 25;
						    font_family = "Noto Sans";
						    rotate = 0; # degrees, counter-clockwise

						    position = "0, 80";
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
						    rotate = 0; # degrees, counter-clockwise

						    position = "0, -100";
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

				    position = "0, -20";
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
			./files/swaylock/effect-blue-filter;

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

				# Dim the screen after 2.5 minutes
				listener = [
					{
						timeout = 150;       # 2.5 min
						on-timeout = "{pkgs.brightnessctl}/bin/brightnessctl -s set 10"; # Set monitor backlight to log
						on-resume = "${pkgs.brightnessctl}/bin/brightnessctl -r";        # Restore monitor backlight
					}

					{
						timeout = 300;       # 5 min
						on-timeout = "${pkgs.systemd}/bin/loginctl lock-session";  # Lock screen after timeout
					}

					{
						timeout = 10;       # Seconds after lock/last interaction
						on-timeout = "${pkgs.procps}/bin/pgrep -x hyprlock && ${dpms_command} off";  # Turn off screen if locked
						on-resume = "${dpms_command} on";  # Screen on
					}

					{
						timeout = 1800;      # 30 min
						on-timeout = "${pkgs.systemd}/bin/systemctl suspend"; # Suspend PC
					}
				];
			};
		};
	};
}
