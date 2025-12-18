# Ladybird Browser Installation
#
# Installs Ladybird browser package.
# Ladybird is a new browser engine and browser built from scratch.
#
# Usage: myModules.apps.browsers.ladybird.enable = true;
{ pkgs, ... }:
{
  description = "Ladybird browser";
  config = {
    environment.systemPackages = [ pkgs.ladybird ];
  };
}
