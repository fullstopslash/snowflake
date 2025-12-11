#!/usr/bin/env sh
# Cycle positions for any media window (does not change focus)
# Usage: cycle-media-positions.sh position1 position2 [position3...]
# Configure media windows in ~/.config/hypr/media-windows.conf
# Dependencies: hyprctl, jq

[ $# -lt 2 ] && exit 1

readonly CONFIG_FILE="${HOME}/.config/hypr/media-windows.conf"
readonly num_positions=$#
readonly DEFAULT_PATTERNS='[
  {"key":"class","val":"mpv"},
  {"key":"title","val":"Picture-in-Picture"},
  {"key":"class","val":"com.github.iwalton3.jellyfin-media-player"},
  {"key":"class","val":"streamlink-twitch-gui"}
]'

# Find media window (single hyprctl call, single jq pass)
patterns=$([ -f "$CONFIG_FILE" ] &&
	jq -Rs 'split("\n")|map(select(test("^[^#]")and length>0)|split("=")|{key:.[0],val:.[1]})' "$CONFIG_FILE" ||
	echo "$DEFAULT_PATTERNS")

result=$(hyprctl clients -j | jq -r --argjson p "$patterns" '
    first(.[]as$c|$p[]as$p|
    if($p.key=="class"and($c.class|test($p.val;"i")))or
       ($p.key=="title"and($c.title|test($p.val;"i")))
    then"\($c.address)|\($c.class)"
    else empty end)//empty
')

[ -z "$result" ] && exit 1

# Parse result (shell built-ins only)
addr=${result%%|*}
ident=${result#*|}

# State file with sanitized identifier
state_file="/tmp/hypr_media_cycle_$(printf '%s' "$ident" | sed 's/[^a-zA-Z0-9]/_/g' | tr '[:upper:]' '[:lower:]')"

# Get current index (minimal I/O)
idx=0
[ -f "$state_file" ] && read -r idx <"$state_file"
[ "$idx" -ge "$num_positions" ] 2>/dev/null && idx=0

# Parse position (pure shell, no external calls)
eval "pos=\${$((idx + 1))}"
set -- $pos

# Apply position (sequential for pixel-exact positioning)
hyprctl dispatch movewindowpixel "exact $1 $2,address:$addr"
hyprctl dispatch resizewindowpixel "exact $3 $4,address:$addr"

# Update state (single write)
echo $(((idx + 1) % num_positions)) >"$state_file"
