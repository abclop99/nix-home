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
$other_monitor_fg_color: $subtext0;

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

/* Workspaces widget. The class says where a workspace lives, not how full it
   is: `empty` means it does not exist yet, so any monitor may claim it;
   `occupied` means it sits on this bar's monitor; `elsewhere` means another
   monitor holds it. The three foregrounds are Catppuccin's own text ramp
   ($text > $subtext0 > $overlay0), so "elsewhere" never reads as "empty". */
.workspace-entry.empty {
	background-color: $bg_color;
	color: $comment_fg_color;
}
.workspace-entry.elsewhere {
	background-color: $bg_color;
	color: $other_monitor_fg_color;
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

/* Compound, not descendant. The hover and click handlers sit on one eventbox
   rather than a nested pair, so `volume` and `icon` are two classes on the same
   element and `.volume .icon` would match nothing at all -- a silent loss of
   colour, since a selector that matches nothing is not an error. */
.volume.icon {
	color: $volume-color;
}
.brightness.icon {
	color: $brightness-color;
}

/* Control popups. The sliders live in their own windows rather than in the
   bar: a revealer takes part in layout, so opening one widened the right-hand
   section and shoved the centred window title sideways on every hover.

   This block MUST sit below the $volume-color / $brightness-color definitions
   above. SCSS resolves variables in source order, and grass treats an
   undefined one as a hard error that fails the WHOLE stylesheet -- which does
   not look like a CSS mistake at all: eww falls back to raw GTK defaults, so
   the entire bar turns white and unstyled.

   .popup-body is the whole window and stays transparent; it is the hover
   target that keeps the popup alive, and is deliberately larger than the
   visible body so the crossing down from the bar has somewhere to land.
   .popup is the part you actually see. */
.popup {
	background-color: $bg_color;
	border-radius: $radius;
	padding: $sep;
}
/* The generic rule above pins min-width for horizontal troughs; a vertical
   one needs the two swapped or it collapses to nothing. */
.popup scale trough {
	min-width: 5px;
	min-height: 120px;
}
.popup.volume highlight {
	background-color: $volume-color;
}
.popup.brightness highlight {
	background-color: $brightness-color;
}
/* Both popups open at the same spot, so each carries its control's glyph --
   otherwise the only thing telling them apart is the slider position. */
.popup label {
	margin-top: $sep;
}
.popup.volume label {
	color: $volume-color;
}
.popup.brightness label {
	color: $brightness-color;
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
