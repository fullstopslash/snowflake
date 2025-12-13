# Laptop role - portable desktop with power management
#
# Extends desktop with: power management, wifi, bluetooth, touchpad
# Uses unified module selection - hosts can override individual categories
# Secret categories: base, desktop, network
{ config, lib, ... }:
{
  config = lib.mkIf (builtins.elem "laptop" config.roles) {
    # ========================================
    # MODULE SELECTIONS (same as desktop)
    # ========================================
    modules = {
      desktop = [
        "plasma"
        "hyprland"
        "wayland"
        "common"
      ];
      displayManager = [ "ly" ];
      apps = [
        "media"
        "gaming"
        "comms"
        "productivity"
      ];
      cli = [
        "shell"
        "tools"
      ];
      development = [
        "latex"
        "document-processing"
        "containers"
      ];
      services = [
        "atuin"
        "ssh"
      ];
      audio = [ "pipewire" ];
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
