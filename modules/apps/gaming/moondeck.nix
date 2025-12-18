# Moondeck Buddy module
#
# Usage: modules.apps.gaming = [ "moondeck" ]
{ pkgs, ... }:
let
  overlay = final: prev: {
    moondeck-buddy = prev.callPackage ../pkgs/moondeck-buddy {
      inherit (final) lib;
    };
  };
in
{
  description = "Moondeck Buddy for Steam Deck streaming";
  config = {
    nixpkgs.overlays = [ overlay ];
    environment.systemPackages = [ pkgs.moondeck-buddy ];
  };
}
