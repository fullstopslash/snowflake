# Wayland support module
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.services.desktop.wayland;
in
{
  options.myModules.services.desktop.wayland = {
    enable = lib.mkEnableOption "Wayland support and utilities";
  };

  config = lib.mkIf cfg.enable {
    # general packages related to wayland
    environment.systemPackages = [
      pkgs.grim # screen capture component, required by flameshot
      pkgs.waypaper # wayland packages(nitrogen analog for wayland)
      pkgs.swww # backend wallpaper daemon required by waypaper
      pkgs.wev # show wayland events, handy for detecting keypress codes
    ];

    # Wayland session variables
    environment.sessionVariables = {
      QT_QPA_PLATFORM = "wayland";
      GDK_BACKEND = "wayland";
      CLUTTER_BACKEND = "wayland"; # for gnome-shell
      SDL_VIDEODRIVER = "wayland"; # for SDL apps
      NIXOS_OZONE_WL = "1"; # for chromium, vscode, electron, etc
      XDG_SESSION_TYPE = "wayland";
      MOZ_ENABLE_WAYLAND = "1"; # for firefox
    };
  };
}
