# Brave Browser Installation
#
# Installs Brave browser package.
# Configuration (command-line args, settings) managed via home-manager.
#
# Usage: myModules.apps.browsers.brave.enable = true;
{ pkgs, ... }:
{
  description = "Brave browser";
  config = {
    environment.systemPackages = [ pkgs.unstable.brave ];
  };
}
