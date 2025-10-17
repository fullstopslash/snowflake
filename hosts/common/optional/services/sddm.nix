{ config, lib, pkgs, ... }:
{
  environment.systemPackages = [ pkgs.sddm-astronaut ];

  services.displayManager.sddm = {
    enable = true;
    enableHidpi = true;
    wayland = {
      enable = true;
      compositor = "kwin";
    };
    theme = "sddm-astronaut-theme";
  };

  # Ensure Hyprland session is available to SDDM and select it by default
  services.displayManager.sessionPackages = [ pkgs.hyprland ];
  services.displayManager.defaultSession = "hyprland";
}


