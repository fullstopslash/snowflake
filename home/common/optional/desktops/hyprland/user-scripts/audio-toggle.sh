#!/usr/bin/env bash

current_state=$(wpctl get-volume @DEFAULT_SINK@ | grep "\[MUTED\]")

if [ -z "$current_state" ]; then
  # Currently unmuted - mute it
  wpctl set-mute @DEFAULT_SINK@ 1
else
  # Currently muted - unmute and restart wireplumber
  wpctl set-mute @DEFAULT_SINK@ 0
  systemctl --user restart wireplumber
fi
