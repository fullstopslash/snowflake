{ config, lib, pkgs, ... }:
{
  environment.systemPackages = [ pkgs.sddm-astronaut ];

  services.displayManager.sddm = {
    enable = true;
    enableHidpi = true;
    wayland.enable = true;
    theme = "sddm-astronaut-theme";
    settings = {
      General = {
        DisplayServer = "wayland";
        GreeterEnvironment = "QT_SCREEN_SCALE_FACTORS=2 QT_WAYLAND_SHELL_INTEGRATION=layer-shell";
      };
      Wayland = {
        CompositorCommand = "Hyprland --no-lockscreen --no-global-shortcuts";
      };
    };
  };
}


