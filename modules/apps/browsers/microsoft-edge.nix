# Microsoft Edge Browser Installation
#
# Installs Microsoft Edge browser package.
# Configuration managed via home-manager if needed.
#
# Usage: myModules.apps.browsers.microsoftEdge.enable = true;
{ pkgs, ... }:
{
  # Microsoft Edge browser
  config = {
    environment.systemPackages = [ pkgs.microsoft-edge ];
  };
}
