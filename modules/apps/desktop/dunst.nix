# Dunst Notification Daemon Installation
#
# Installs Dunst notification daemon for desktop notifications.
# Configuration managed via home-manager.
#
# Usage: myModules.apps.desktop.dunst.enable = true;
{ pkgs, ... }:
{
  description = "Dunst - Notification daemon";
  config = {
    environment.systemPackages = [ pkgs.dunst ];
  };
}
