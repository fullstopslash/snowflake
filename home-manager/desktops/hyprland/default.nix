# Hyprland Home Manager Config
#
# Package installation via: myModules.apps.window-managers.hyprland.enable = true
# This module provides Hyprland user-level configuration only.
#
# This module just enables hyprland and deploys user scripts.
# All hyprland settings (keybinds, appearance, etc.) are managed via raw config files
# in ./host-configs/ which get deployed to ~/.config/hypr/
#
# To edit hyprland config, edit:
#   - host-configs/common.conf     (shared settings)
#   - host-configs/<hostname>.conf (host-specific settings)
#
# See also:
#   - host-config-link.nix (deploys config files)
#   - /modules/services/desktop/hyprland.nix (NixOS system config)
{
  pkgs,
  lib,
  config,
  ...
}:
let
  # User scripts directory
  scriptsDir = ./user-scripts;

  # List of scripts to deploy
  scriptNames = [
    "audio-toggle.sh"
    "cycle-media-positions.sh"
    "cycle-window-positions.sh"
    "focus-or-launch.sh"
    "focus-priority-or-fallback.sh"
    "fullscreen-media-toggle.sh"
    "hypridle.sh"
    "isolate-focused-window.sh"
    "kde-theme-lightweight.sh"
    "kde-theme.sh"
    "media-follower.sh"
    "media-gap.sh"
    "move-media-window.sh"
    "pin-and-float.sh"
    "restart-hypridle.sh"
  ];
in
{
  imports = [
    ./hyprlock.nix
    ./wlogout.nix
  ];

  # Enable hyprland window manager
  wayland.windowManager.hyprland = {
    enable = true;
    systemd = {
      enable = true;
      variables = [ "--all" ]; # fix for https://wiki.hyprland.org/Nix/Hyprland-on-Home-Manager/#programs-dont-work-in-systemd-services-but-do-on-the-terminal
    };

    # Plugins (disabled for griefling VM to avoid build issues)
    plugins = lib.mkIf (config.identity.hostName != "griefling") [
      pkgs.hyprlandPlugins.hy3
    ];

    # Point to raw config files - all settings managed there, not in Nix
    # Config files are deployed by host-config-link.nix to ~/.config/hypr/
    extraConfig = ''
      # Config managed by raw config files, not Nix
      # Edit: host-configs/common.conf and host-configs/<hostname>.conf
    '';
  };

  # Deploy user scripts to ~/.config/hypr/scripts/
  home.file = builtins.listToAttrs (
    map (name: {
      name = ".config/hypr/scripts/${name}";
      value = {
        source = "${scriptsDir}/${name}";
        executable = true;
      };
    }) scriptNames
  );
}
