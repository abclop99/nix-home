{ config, pkgs, ... }: {

	config = {

		# Other packages
		home.packages = with pkgs; [
	    networkmanagerapplet    # Systray for NetworkManager
	    grimblast               # Screenshot tool for hyprland
			swaynotificationcenter  # Notification center
			
			# Used in eww's scripts
			# TODO: Wrap dependencies in the scripts?
			jq
			socat
			python3
		];
	
	  # Hyprland itself
	  wayland.windowManager.hyprland = {
	    enable = true;
	    # enableNvidiaPatches = true;
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
	        "$mod, D, exec, $menu"
	        "$mod, RETURN, exec, $terminal"
	        ", Print, exec, grimblast copy area"
					"$mod, L, exec, $lock"

					# Keybinds for window managment
					"$mod SHIFT, Q, killactive"
	        "$mod, F, fullscreen, 1"
	        "$mod SHIFT, F, fullscreen, 0"

	        # Move focus using mod + arrow keys
	        "$mod, left, movefocus, l"
	        "$mod, right, movefocus, r"
	        "$mod, up, movefocus, u"
	        "$mod, down, movefocus, d"

	        # Move windows using mod + arrow keys
	        "$mod SHIFT, left, movewindow, l"
	        "$mod SHIFT, right, movewindow, r"
	        "$mod SHIFT, up, movewindow, u"
	        "$mod SHIFT, down, movewindow, d"

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
				# TODO: Doesn't seem to be working
				bindm = [
					"$mod, mouse:272, moveWindow"
					"$mod, mouse:273, resizeWindow"
				];
				
	    };
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
	};
}
