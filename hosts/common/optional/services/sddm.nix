{ config, lib, pkgs, ... }:
{

  services.displayManager.sddm = {
    enable = true;
    enableHidpi = true;
    package = pkgs.sddm-qt6;
    # themePackages not available on this NixOS; install theme via systemPackages
    wayland = {
      enable = true;
    };
    theme = "sddm-astronaut-theme";
    # settings = {
    #   Theme = {
    #     Current = "sddm-astronaut";
    #   };
    # };
  };

  # Ensure the theme is present for SDDM to discover
  environment.systemPackages = [
    pkgs.sddm-astronaut
    pkgs.kdePackages.qtmultimedia
    pkgs.kdePackages.qtdeclarative
  ];

  # Ensure Hyprland session is available to SDDM and select it by default
  services.displayManager.sessionPackages = [ pkgs.hyprland ];
  services.displayManager.defaultSession = "hyprland";
}


