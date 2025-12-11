# Wayland support module
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.desktop.wayland;
in
{
  options.myModules.desktop.wayland = {
    enable = lib.mkEnableOption "Wayland support and utilities";
  };

  config = lib.mkIf cfg.enable {
    # general packages related to wayland
    environment.systemPackages = [
      pkgs.grim # screen capture component, required by flameshot
      pkgs.waypaper # wayland packages(nitrogen analog for wayland)
      pkgs.swww # backend wallpaper daemon required by waypaper
    ];
  };
}
