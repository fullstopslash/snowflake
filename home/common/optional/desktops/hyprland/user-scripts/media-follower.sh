#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Hyprland Media Follower
# -----------------------------------------------------------------------------
# This script listens for workspace changes and moves a designated "media"
# window to the new workspace, positioning it on the top-right.
# -----------------------------------------------------------------------------

# --- CONFIGURATION ---
# Add new rules to this jq filter to make other windows follow.
# Each rule should be a valid jq 'select()' condition, combined with 'or'.
# For example:
#   (.class == "mpv") or
#   (.class == "firefox" and .title == "Picture-in-Picture")
# -----------------------------------------------------------------------------
JQ_RULES='(
  (.class == "mpv") or
  (.class == "firefox" and .title == "Picture-in-Picture")
)'

# -----------------------------------------------------------------------------
# SCRIPT LOGIC
# -----------------------------------------------------------------------------

# Finds the address of the first window that matches the JQ_RULES.
get_media_window_address() {
  hyprctl clients -j | jq -r ".[] | select(${JQ_RULES}) | select(.floating == false) | .address" | head -1
}

# Repositions a given window to the specified workspace.
reposition_window() {
  local address="$1"
  local workspace_name="$2"

  # 1. Get monitor data for the target workspace.
  local monitor_data
  monitor_data=$(hyprctl monitors -j | jq -r --arg ws "$workspace_name" '.[] | select(.activeWorkspace.name == $ws)')
  if [ -z "$monitor_data" ]; then
    return
  fi

  # 2. Calculate desired size and position.
  local monitor_width margin window_width window_height target_x target_y
  monitor_width=$(echo "$monitor_data" | jq -r '.width')
  margin=10
  window_width=$((monitor_width / 3))
  window_height=$((window_width * 9 / 16))
  target_x=$((monitor_width - window_width - margin))
  target_y=$margin

  # 3. Dispatch all movements in a single batch for efficiency.
  hyprctl --batch \
    "dispatch movetoworkspacesilent $workspace_name,address:$address;" \
    "dispatch resizewindowpixel exact $window_width $window_height,address:$address;" \
    "dispatch movewindowpixel exact $target_x $target_y,address:$address"
}
# "keyword animation workspaces,0;" \

# Main function to listen for events and orchestrate the process.
main() {
  # 1. Get Hyprland instance signature for the socket path.
  local signature
  if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    signature=$(hyprctl instances -j | jq -r '.[] | select(.active == true) | .instance')
  else
    signature="$HYPRLAND_INSTANCE_SIGNATURE"
  fi
  local socket_path="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/$signature/.socket2.sock"

  # 2. Listen for workspace change events.
  socat - "UNIX-CONNECT:$socket_path" | while read -r line; do
    if [ "${line#workspace>>}" != "$line" ]; then
      # Add a small delay to prevent race conditions where Hyprland hasn't updated its state yet.
      sleep 0.1
      local workspace_name
      workspace_name=${line##*>>}

      local media_address
      media_address=$(get_media_window_address)

      if [ -n "$media_address" ] && [ "$media_address" != "null" ]; then
        reposition_window "$media_address" "$workspace_name"

        # 3. Re-enable animations after a short delay.
        # sleep 0.1
        # hyprctl keyword animation "workspaces,1,default,slidefadevert"
      fi
    fi
  done
}

main
