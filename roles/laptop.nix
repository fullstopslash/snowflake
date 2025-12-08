{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  # Laptop imports same modules as desktop plus laptop-specific ones
  imports = [
    # Desktop environment (same as desktop role)
    ../modules/services/desktop
    ../modules/services/audio

    # Applications (same as desktop role)
    ../modules/apps/cli
    ../modules/apps/fonts
    ../modules/apps/media
    ../modules/apps/gaming
    ../modules/apps/theming
    ../modules/apps/development

    # Services (same as desktop role)
    ../modules/services/networking
    ../modules/services/development
    ../modules/services/security
    ../modules/services/ai
  ];

  # Laptop-specific config
  config = lib.mkIf cfg.laptop {
    # Desktop-like defaults
    services.xserver.enable = lib.mkDefault true;
    hardware.graphics.enable = lib.mkDefault true;

    # Laptop-specific: Power management
    services.thermald.enable = lib.mkDefault true;
    services.power-profiles-daemon.enable = lib.mkDefault true;
    powerManagement.enable = lib.mkDefault true;

    # Laptop-specific: Wifi by default
    networking.wireless.enable = lib.mkDefault false; # Use networkmanager instead
    networking.networkmanager.wifi.powersave = lib.mkDefault true;

    # Laptop-specific: Hardware
    services.libinput.enable = lib.mkDefault true;
    hardware.bluetooth.enable = lib.mkDefault true;
  };
}
