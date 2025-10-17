{ config, lib, pkgs, ... }:
{

  services.displayManager.sddm = {
    enable = true;
    enableHidpi = true;
    themePackages = [ pkgs.sddm-astronaut ];
    wayland = {
      enable = true;
      compositor = "kwin";
    };
    theme = "sddm-astronaut";
    settings = {
      Theme = {
        Current = "sddm-astronaut";
      };
    };
  };

  # Ensure Hyprland session is available to SDDM and select it by default
  services.displayManager.sessionPackages = [ pkgs.hyprland ];
  services.displayManager.defaultSession = "hyprland";
}


