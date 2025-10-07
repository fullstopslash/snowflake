{
  lib,
  config,
  pkgs,
  ...
}:
let
  #
  # ========== Arrange Tiles According to Preference ==========
  #
  arrangeTiles = pkgs.writeShellApplication {
    name = "arrangeTiles";
    text = ''
      #!/usr/bin/env bash

      function dispatch(){
          hyprctl dispatch -- "$1"
      }

      # Arrange upper tiles
      dispatch "focuswindow class:signal"
      dispatch "hy3:movewindow l"
      dispatch "hy3:movewindow l" #make sure signal starts in the left most position
      dispatch "hy3:movewindow l"
      dispatch "hy3:changegroup toggletab"
        #TODO: detect if brave is a single window with "restore session" prompt or two windows
      dispatch "focuswindow class:brave-browser"
      dispatch "hy3:movewindow r"
      dispatch "hy3:movewindow r"
      dispatch "hy3:movewindow r" #make sure brave exits the group #TODO: is the a bind to move drop it from group
      dispatch "hy3:makegroup v"

      # arrange rightside tiles
      dispatch "focuswindow title:Virtual Machine Manager"
      dispatch "hy3:movewindow l"
      dispatch "resizeactive exact 500 900" #these values are fuzzy because hypr has some sort of multiple that reduces the values here
      dispatch "focuswindow title:amdgpu_top"
      dispatch "hy3:movewindow r"
      dispatch "resizeactive exact 500, 900"
      dispatch "focuswindow title:btop"
      #dispatch "resizeactive exact 1350 900"
      dispatch "focuswindow class:spotify"
      dispatch "hy3:movewindow d"
      dispatch "hy3:movewindow d" #move down twice to handle scenarios where spotify launches early than usual
    '';
  };

  #
  # ========== Monitor Toggling ==========
  #
  primaryMonitor = lib.head (lib.filter (m: m.primary) config.monitors);

  # Toggle all monitors
  toggleMonitors = pkgs.writeShellApplication {
    name = "toggleMonitors";
    text = ''
      #!/bin/bash

      # Function to get all monitor names
      get_all_monitors() {
          hyprctl monitors -j | jq -r '.[].name'
      }

      # Function to check if all monitors are on
      all_monitors_on() {
          for monitor in $(get_all_monitors); do
              state=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$monitor\") | .dpmsStatus")
              if [ "$state" != "true" ]; then
                  return 1
              fi
          done
          return 0
      }

      # Main logic
      if all_monitors_on; then
          # If all monitors are on, put all except primary into standby
          for monitor in $(get_all_monitors); do
             hyprctl dispatch dpms standby "$monitor"
          done
          echo "All monitors are now in standby mode."
      else
          # If not all monitors are on, turn them all on
          for monitor in $(get_all_monitors); do
              hyprctl dispatch dpms on "$monitor"
          done
          echo "All monitors are now on."
      fi    '';
  };

  # Toggle all non-primary monitors
  #dpms standby seems to be working but if monitor wakeup is too sensitive for gaming, can try suspend or off instead
  toggleMonitorsNonPrimary = pkgs.writeShellApplication {
    name = "toggleMonitorsNonPrimary";
    text = ''
      #!/bin/bash

      # Define your primary monitor (the one you want to keep on)
      PRIMARY_MONITOR="${primaryMonitor.name}"  # Replace with your primary monitor name

      # Function to get all monitor names
      get_all_monitors() {
          hyprctl monitors -j | jq -r '.[].name'
      }

      # Function to check if all monitors are on
      all_monitors_on() {
          for monitor in $(get_all_monitors); do
              state=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$monitor\") | .dpmsStatus")
              if [ "$state" != "true" ]; then
                  return 1
              fi
          done
          return 0
      }

      # Main logic
      if all_monitors_on; then
          # If all monitors are on, put all except primary into standby
          for monitor in $(get_all_monitors); do
              if [ "$monitor" != "$PRIMARY_MONITOR" ]; then
                  hyprctl dispatch dpms standby "$monitor"
              fi
          done
          echo "All monitors except $PRIMARY_MONITOR are now in standby mode."
      else
          # If not all monitors are on, turn them all on
          for monitor in $(get_all_monitors); do
              hyprctl dispatch dpms on "$monitor"
          done
          echo "All monitors are now on."
      fi    '';
  };
in
{
  home.packages = [
    arrangeTiles
    toggleMonitors
    toggleMonitorsNonPrimary
  ];
}
