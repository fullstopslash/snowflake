#!/usr/bin/env bash

# Hyprland Window Position Cycler
# Usage: ./cycle_window_positions.sh position1 position2 position3 ... window_identifier
# Example: ./cycle_window_positions.sh "0 0 1920 1080" "1920 0 1920 1080" "960 540 960 540" "firefox"

# Check if arguments were provided (minimum 2: one position and one window identifier)
if [ $# -lt 2 ]; then
    echo "Usage: $0 <position1> [position2] [position3] ... <window_identifier>"
    echo "Positions should be in format: 'x y width height'"
    echo "Window identifier can be class name or title (partial matches work)"
    echo "Example: $0 '0 0 1920 1080' '1920 0 1920 1080' 'firefox'"
    exit 1
fi

# Get all arguments
args=("$@")
num_args=${#args[@]}

# Last argument is the window identifier
window_identifier="${args[-1]}"

# All arguments except the last are positions
positions=("${args[@]:0:$((num_args-1))}")
num_positions=${#positions[@]}

# Create a state file to track current position index (unique per window)
state_file="/tmp/hyprland_window_cycle_state_$(echo "$window_identifier" | tr '[:space:]' '_' | tr '[:upper:]' '[:lower:]')"

# Get current position index (default to 0 if file doesn't exist)
if [ -f "$state_file" ]; then
    current_index=$(cat "$state_file")
    # Validate the index
    if ! [[ "$current_index" =~ ^[0-9]+$ ]] || [ "$current_index" -ge "$num_positions" ]; then
        current_index=0
    fi
else
    current_index=0
fi

# Get the current position
current_position="${positions[$current_index]}"

# Parse the position string
read -r x y width height <<< "$current_position"

# Validate position parameters
if ! [[ "$x" =~ ^-?[0-9]+$ ]] || ! [[ "$y" =~ ^-?[0-9]+$ ]] || ! [[ "$width" =~ ^[0-9]+$ ]] || ! [[ "$height" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid position format '$current_position'"
    echo "Expected format: 'x y width height' (integers only)"
    exit 1
fi

# Get the target window by class or title
target_window=""

# First try to find by class
windows_by_class=$(hyprctl clients -j | jq -r ".[] | select(.class | test(\"$window_identifier\"; \"i\")) | .address")
if [ -n "$windows_by_class" ]; then
    target_window=$(echo "$windows_by_class" | head -n 1)
fi

# If no match by class, try by title
if [ -z "$target_window" ]; then
    windows_by_title=$(hyprctl clients -j | jq -r ".[] | select(.title | test(\"$window_identifier\"; \"i\")) | .address")
    if [ -n "$windows_by_title" ]; then
        target_window=$(echo "$windows_by_title" | head -n 1)
    fi
fi

if [ -z "$target_window" ]; then
    echo "No window found matching identifier: $window_identifier"
    exit 1
fi

# Move and resize the window
hyprctl dispatch movewindowpixel exact $x $y,address:$target_window
hyprctl dispatch resizewindowpixel exact $width $height,address:$target_window

# Calculate next index (cycle back to 0 after reaching the end)
next_index=$(( (current_index + 1) % num_positions ))

# Save the next index for the next run
echo "$next_index" > "$state_file"

# Optional: Print current action for debugging
echo "Moved window '$window_identifier' to position $((current_index + 1))/$num_positions: ${current_position}"
echo "Next position will be: ${positions[$next_index]}"

# Hyprland Configuration Examples:
# Add these to your ~/.config/hypr/hyprland.conf file:
#
# # Firefox window cycling (left half, right half, center)
# bind = SUPER, F, exec, /path/to/cycle_window_positions.sh "0 0 960 1080" "960 0 960 1080" "480 270 960 540" "firefox"
#
# # Terminal cycling (top-right, bottom-right, fullscreen) - assuming 1920x1080 display
# bind = SUPER, K, exec, /path/to/cycle_window_positions.sh "960 0 960 540" "960 540 960 540" "0 0 1920 1080" "kitty"
#
# # VSCode cycling (left half, right half, top-right quarter, bottom-right quarter)
# bind = SUPER, C, exec, /path/to/cycle_window_positions.sh "0 0 960 1080" "960 0 960 1080" "960 0 960 540" "960 540 960 540" "code"
#
# # Discord cycling (top-right corner, bottom-right corner)
# bind = SUPER, D, exec, /path/to/cycle_window_positions.sh "1440 0 480 540" "1440 540 480 540" "discord"
#
# # Any window by title containing "YouTube" 
# bind = SUPER, Y, exec, /path/to/cycle_window_positions.sh "960 0 960 540" "960 540 960 540" "YouTube"
