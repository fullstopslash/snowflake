# Desktop utilities and tools
#
# General desktop utilities that aren't media, gaming, or productivity specific.
#
# Usage:
#   myModules.apps.desktop.enable = true;
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.apps.desktop;
in
{
  options.myModules.apps.desktop = {
    enable = lib.mkEnableOption "Desktop utilities and tools";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Screenshots
      grimblast

      # Device imaging
      rpi-imager
    ];
  };
}
