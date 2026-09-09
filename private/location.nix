# Theme schedule. Tracked in git with placeholder content; the real values live
# only on disk via `git update-index --skip-worktree` (see CLAUDE.md "Private
# files"). Consumed by modules/theme.nix.
#
# Coordinates are per-user, so they are null here rather than a working default.
# With them null, darkman is given no location and its automatic transitions are
# off; the fixed times below drive the theme instead. Both are valid states, so
# an unpopulated copy of this file is not an error -- it just schedules by the
# clock rather than by the sun.
{
  latitude = null;
  longitude = null;

  # Used only while latitude/longitude are null. HH:MM:SS, may wrap midnight.
  # 07:00 lines the light transition up with hyprshade's blue-light filter
  # turning off (modules/hyprland.nix), which a solar sunrise drifts against.
  lightAt = "07:00:00";
  darkAt = "19:00:00";
}
