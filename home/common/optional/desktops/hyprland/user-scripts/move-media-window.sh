#!/usr/bin/env sh
# Move any media window to a specific position (does not change focus)
# Usage: move-media-window.sh <x> <y> <width> <height>
# Configure media windows in ~/.config/hypr/media-windows.conf
# Dependencies: hyprctl, jq

[ $# -ne 4 ] && exit 1

readonly CONFIG_FILE="${HOME}/.config/hypr/media-windows.conf"
readonly DEFAULT_PATTERNS='[
  {"key":"class","val":"mpv"},
  {"key":"title","val":"Picture-in-Picture"},
  {"key":"class","val":"com.github.iwalton3.jellyfin-media-player"},
]'

# Find media window (single hyprctl call, single jq pass)
patterns=$([ -f "$CONFIG_FILE" ] &&
    jq -Rs 'split("\n")|map(select(test("^[^#]")and length>0)|split("=")|{key:.[0],val:.[1]})' "$CONFIG_FILE" ||
    echo "$DEFAULT_PATTERNS")

addr=$(hyprctl clients -j | jq -r --argjson p "$patterns" '
    first(.[]as$c|$p[]as$p|
    if($p.key=="class"and($c.class|test($p.val;"i")))or
       ($p.key=="title"and($c.title|test($p.val;"i")))
    then$c.address
    else empty end)//empty
')

# Exit silently if no media window found
[ -z "$addr" ] && exit 0

# Apply position directly - pinned windows CAN be moved
hyprctl dispatch movewindowpixel "exact $1 $2,address:$addr"
hyprctl dispatch resizewindowpixel "exact $3 $4,address:$addr"
