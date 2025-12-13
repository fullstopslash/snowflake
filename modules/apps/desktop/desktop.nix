# Desktop utilities and tools
#
# General desktop utilities that aren't media, gaming, or productivity specific.
#
# Usage: modules.apps.desktop = [ "desktop" ]
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.apps.desktop.desktop;
in
{
  options.myModules.apps.desktop.desktop = {
    enable = lib.mkEnableOption "Desktop utilities and tools";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      grimblast
      rpi-imager
    ];
  };
}
