# Laptop role - portable desktop with power management
#
# Extends desktop with: power management, wifi, bluetooth, touchpad
# Uses unified module selection - hosts can override individual categories
# Secret categories: base, desktop, network
{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  config = lib.mkIf cfg.laptop {
    # ========================================
    # MODULE SELECTIONS (same as desktop)
    # ========================================
    modules = {
      desktop = lib.mkDefault [ "plasma" "hyprland" "wayland" "common" ];
      displayManager = lib.mkDefault [ "ly" ];
      apps = lib.mkDefault [ "media" "gaming" "comms" "productivity" ];
      cli = lib.mkDefault [ "shell" "tools" ];
      development = lib.mkDefault [ "latex" "document-processing" "containers" ];
      services = lib.mkDefault [ "atuin" "ssh" ];
      audio = lib.mkDefault [ "pipewire" ];
    };

    # ========================================
    # SYSTEM DEFAULTS
    # ========================================
    services.xserver.enable = lib.mkDefault true;
    hardware.graphics.enable = lib.mkDefault true;

    # Laptop-specific: Power management
    services.thermald.enable = lib.mkDefault true;
    services.power-profiles-daemon.enable = lib.mkDefault true;
    powerManagement.enable = lib.mkDefault true;

    # Laptop-specific: Wifi
    networking.wireless.enable = lib.mkDefault false; # Use networkmanager
    networking.networkmanager.wifi.powersave = lib.mkDefault true;

    # Laptop-specific: Hardware
    services.libinput.enable = lib.mkDefault true;
    hardware.bluetooth.enable = lib.mkDefault true;

    # ========================================
    # HOSTSPEC (non-derived options only)
    # ========================================
    hostSpec = {
      wifi = lib.mkDefault true;
      isMobile = lib.mkDefault true;

      secretCategories = {
        base = lib.mkDefault true;
        desktop = lib.mkDefault true;
        network = lib.mkDefault true;
        cli = lib.mkDefault true;
      };
    };
  };
}
