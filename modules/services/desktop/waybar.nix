# Waybar status bar module
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.services.desktop.waybar;
in
{
  options.myModules.services.desktop.waybar = {
    enable = lib.mkEnableOption "Waybar status bar";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.waybar
      pkgs.pavucontrol
      pkgs.bluez
      pkgs.blueman
      pkgs.kdePackages.kdeconnect-kde
    ];
  };
}
