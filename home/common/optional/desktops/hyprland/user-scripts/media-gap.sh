#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Hyprland Media Gap Manager
# -----------------------------------------------------------------------------
# This script creates a "gap" on a monitor for a floating/pinned media window,
# allowing it to be always visible without obscuring tiled windows.
# It listens for media windows opening and closing to manage the gaps.
# -----------------------------------------------------------------------------

# --- CONFIGURATION ---
# Rules to identify which windows should trigger the gap.
# Must be a valid jq 'select()' condition.
# -----------------------------------------------------------------------------
JQ_RULES='(
  (.class == "mpv") or
  (.class == "firefox" and .title == "Picture-in-Picture")
)'

# --- SCRIPT LOGIC ---

# Directory to store state files for each monitor with an active media gap.
STATE_DIR="/tmp/hypr-media-gap"

# This function is called when a new window opens.
handle_window_open() {
  local event_data="$1"
  local window_address=${event_data%%,*}

  # 1. Get the full details of the newly opened window.
  local client
  client=$(hyprctl clients -j | jq -r --arg addr "$window_address" '.[] | select(.address == $addr)')

  # 2. Check if the new window matches our media rules.
  local is_media_window
  is_media_window=$(echo "$client" | jq -r "select(${JQ_RULES}) | .address")

  if [ -z "$is_media_window" ]; then
    return # Not a media window, do nothing.
  fi

  # 3. Get monitor details for the window.
  local monitor_id
  monitor_id=$(echo "$client" | jq -r '.monitor')
  local monitor_data
  monitor_data=$(hyprctl monitors -j | jq -r --argjson id "$monitor_id" '.[] | select(.id == $id)')
  local monitor_width
  monitor_width=$(echo "$monitor_data" | jq -r '.width')
  local monitor_name
  monitor_name=$(echo "$monitor_data" | jq -r '.name')

  # 4. Store the monitor's current gap settings before we change them.
  local current_gaps
  current_gaps=$(hyprctl getoption general:gaps_out -j | jq -r '.str')
  echo "$current_gaps" >"$STATE_DIR/$monitor_name.gaps"
  echo "$window_address" >"$STATE_DIR/$monitor_name.addr"

  # 5. Calculate new gaps and window position.
  local margin=10
  local window_width=$((monitor_width / 3))
  local window_height=$((window_width * 9 / 16))
  local target_x=$((monitor_width - window_width - margin))
  local target_y=$margin
  local new_right_gap=$((window_width + margin))

  # 6. Apply the new gap and move the window into it.
  hyprctl keyword monitor "$monitor_name,gaps:10 $new_right_gap 10 10"
  hyprctl dispatch movewindowpixel "exact $target_x $target_y,address:$window_address"
  hyprctl dispatch resizewindowpixel "exact $window_width $window_height,address:$window_address"
}

# This function is called when a window closes.
handle_window_close() {
  local closed_address="$1"
  local monitor_name

  # Find if the closed window is one we are managing.
  for f in "$STATE_DIR"/*.addr; do
    if [ -f "$f" ] && [ "$(cat "$f")" = "$closed_address" ]; then
      monitor_name=$(basename "$f" .addr)
      break
    fi
  done

  if [ -n "$monitor_name" ]; then
    # Restore the original gaps.
    local original_gaps
    original_gaps=$(cat "$STATE_DIR/$monitor_name.gaps")
    hyprctl keyword general:gaps_out "$original_gaps"

    # Clean up state files.
    rm -f "$STATE_DIR/$monitor_name.addr" "$STATE_DIR/$monitor_name.gaps"
  fi
}

# Main function to listen for events.
main() {
  mkdir -p "$STATE_DIR"

  local socket_path="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"

  socat - "UNIX-CONNECT:$socket_path" | while read -r line; do
    case "$line" in
    "openwindow>>"*)
      handle_window_open "${line#openwindow>>}"
      ;;
    "closewindow>>"*)
      handle_window_close "${line#closewindow>>}"
      ;;
    esac
  done
}

main
