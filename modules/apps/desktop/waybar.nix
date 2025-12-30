# Waybar Status Bar Installation
#
# Installs Waybar status bar for Wayland compositors.
# Configuration managed via home-manager.
#
# Usage: myModules.apps.desktop.waybar.enable = true;
{ pkgs, ... }:
{
  # Waybar - Status bar for Wayland
  config = {
    environment.systemPackages = [
      pkgs.waybar
      pkgs.pavucontrol # Volume control (for waybar)
      pkgs.bluez # Bluetooth support
      pkgs.blueman # Bluetooth manager
      pkgs.kdePackages.kdeconnect-kde # Phone integration
    ];
  };
}
