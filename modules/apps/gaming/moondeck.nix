# Moondeck Buddy module
#
# Usage: modules.apps.gaming = [ "moondeck" ]
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.apps.gaming.moondeck;
  overlay = final: prev: {
    moondeck-buddy = prev.callPackage ../pkgs/moondeck-buddy {
      inherit (final) lib;
    };
  };
in
{
  options.myModules.apps.gaming.moondeck = {
    enable = lib.mkEnableOption "Moondeck Buddy for Steam Deck streaming";
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [ overlay ];
    environment.systemPackages = [ pkgs.moondeck-buddy ];
  };
}
