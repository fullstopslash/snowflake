#!/usr/bin/env bash
# Save as ~/.config/hypr/scripts/focus-or-launch.sh

app_class="$1"
app_command="$2"

# Check if the application is already running
if hyprctl clients | grep -q "class: $app_class"; then
  # Focus the existing window
  hyprctl dispatch focuswindow "class:$app_class"
else
  # Launch the application
  exec $app_command &
fi
