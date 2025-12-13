#!/usr/bin/env bash
# Move all unfocused windows from current workspace to target workspace
# Keeps the focused window and pinned windows in place
# Usage: isolate-focused-window.sh <target_workspace>
# Dependencies: hyprctl, jq

[ $# -ne 1 ] && {
	echo "Usage: $0 <target_workspace_number>"
	exit 1
}

target_workspace="$1"

# Single activewindow call to get focus and workspace
active_info=$(hyprctl activewindow -j)
# Variables focused_addr and current_ws are assigned via eval
eval "$(jq -r '@sh "focused_addr=\(.address) current_ws=\(.workspace.id)"' <<<"$active_info")"

# Single clients call, extract all unpinned unfocused addresses in one jq pass
# shellcheck disable=SC2154
unfocused=$(hyprctl clients -j | jq -r --arg ws "$current_ws" --arg focused "$focused_addr" '
    [.[]|select(.workspace.id==($ws|tonumber)and.address!=$focused and.pinned!=true)|.address]|
    map("dispatch movetoworkspacesilent \($ARGS.positional[0]),address:\(.)")|
    join("; ")
' --args "$target_workspace")

# Batch move all windows in single hyprctl call
[ -n "$unfocused" ] && hyprctl --batch "$unfocused"
