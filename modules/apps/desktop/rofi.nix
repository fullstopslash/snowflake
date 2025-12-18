# Rofi Application Launcher Installation
#
# Installs rofi-wayland for Wayland-compatible application launcher.
# Configuration managed via home-manager.
#
# Usage: myModules.apps.desktop.rofi.enable = true;
{ pkgs, ... }:
{
  description = "Rofi - Application launcher for Wayland";
  config = {
    environment.systemPackages = [ pkgs.rofi-wayland ];
  };
}
