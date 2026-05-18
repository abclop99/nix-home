{ palette }:
''
/*
Theming for eww bar (generated from modules/theme.nix; palette tokens
are interpolated from theme.palette; the body is hand-written SCSS).
*/

/* Catppuccin palette tokens */
$base:     ${palette.base};
$mantle:   ${palette.mantle};
$surface0: ${palette.surface0};
$surface1: ${palette.surface1};
$surface2: ${palette.surface2};
$text:     ${palette.text};
$subtext0: ${palette.subtext0};
$overlay0: ${palette.overlay0};
$red:      ${palette.red};
$peach:    ${palette.peach};
$yellow:   ${palette.yellow};
$green:    ${palette.green};
$teal:     ${palette.teal};
$sky:      ${palette.sky};
$blue:     ${palette.blue};
$mauve:    ${palette.mauve};

/* Back-compat aliases for existing call-sites */
$orange: $peach;
$purple: $mauve;

/* Semantic aliases */
$bg_color:           $base;
$fg_color:           $text;
$selection_bg_color: $surface1;
$selection_fg_color: $text;
$hover_bg_color:     $surface0;
$comment_fg_color:   $overlay0;

/* Other variables */
$radius: 5px;
$sep: 5px;
$animation_duration: 0.2s;

/* Cofigure CSS transitions */
* {
	transition-property: opacity, width, height, background-color, color;
	transition-duration: $animation_duration;
	transition-timing-function: ease-out;
}

window {
	background: transparent;
	font-family: sans-serif, "Symbols Nerd Font";
}

.section {
	background-color: $bg_color;
	color: $fg_color;

	padding-left: $radius;
	padding-right: $radius;

	border-radius: $radius;
}

/* Workspaces widget */
.workspace-entry.empty {
	background-color: $bg_color;
	color: $comment_fg_color;
}
.workspace-entry.occupied {
	background-color: $bg_color;
	color: $fg_color;
}
.workspace-entry.current {
	background-color: $selection_bg_color;
	color: $selection_fg_color;
}
.workspace-entry:hover {
	background-color: $hover_bg_color;
}

/* Center (window title) */
.section.center.empty {
	opacity: 0;
}

/* Right */
.separator {
	color: $comment_fg_color;
	font-weight: bold;
	font-size: 22px;
	margin: 0px $sep 0px $sep;
}
.module {
}
.module .item {
	margin-left: 2px;
	margin-right: 2px;
}

/* Control sliders */
scale {
	// border: 1px solid $red;
	padding-right: $sep;
	padding-left: $sep;
}
scale trough {
	min-height: 5px;
	min-width: 50px;
	border-radius: 10px;

	background-color: $surface0;
	box-shadow: none;
	border: none;
}
scale trough highlight {
	background-color: $teal;
	border: 0;
	border-radius: 10px;
}
/* Hide the slider while keeping it */
scale slider {
	background: none;
	border: none;
	box-shadow: none;
}

/* Fix the width of the icons to prevent unequal and changing widths */
.controls .icon label {
	min-width: 13px;
}

/* Colors for the brightness and volume sliders and icons */
$volume-color: $orange;
$brightness-color: $yellow;

.volume .icon {
	color: $volume-color;
}
.volume highlight {
	background-color: $volume-color;
}
.brightness .icon {
	color: $brightness-color;
}
.brightness highlight {
	background-color: $brightness-color;
}

/* System info circular bars */
.system-info .circular-progress {
	background-color: $surface0;
}
.system-info .circular-progress label {
	font-size: 80%;
	margin: 5px;
}

/* System info battery */
.system-info .circular-progress.battery.low {
	color: $red;
}
.system-info .circular-progress.battery.medium {
	color: $fg_color;
}
.system-info .circular-progress.battery.high {
	color: $green;
}
.system-info .circular-progress.battery label {
	color: $fg_color;
	font-size: 80%;
	margin: 6px;
}
.system-info .circular-progress.battery label.charging {
	color: $green;
}
.system-info .circular-progress.battery label.discharging {
	color: $yellow;
}
.system-info .circular-progress.battery label.not_charging {
	color: $fg_color;
}
.system-info .circular-progress.battery label.full {
	color: $green;
}
.system-info .circular-progress.battery label.unknown {
	color: $purple;
}

/* Clock stuff */
.clock .date {
	margin-right: $sep;
}
.clock .percent {
	color: $sky;
	margin-left: 5px;
}
.clock .percent .hour-percent {
	color: $blue;
	margin: 5px;
}
''
