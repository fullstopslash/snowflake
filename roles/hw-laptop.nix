# Laptop role - portable desktop with power management
#
# Extends desktop with: power management, wifi, bluetooth, touchpad
# Sets: isMobile, wifi hostSpec values in addition to desktop values
# Secret categories: base, desktop, network
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

    # Desktop-relevant optional modules (files that exist)
    (lib.custom.relativeToRoot "hosts/common/optional/hyprland.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/wayland.nix")
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

    # Laptop hostSpec defaults - hosts can override with lib.mkForce
    hostSpec = {
      # Behavioral defaults specific to laptop
      useWayland = lib.mkDefault true;
      useWindowManager = lib.mkDefault true;
      isDevelopment = lib.mkDefault true;
      wifi = lib.mkDefault true; # Laptops always have wifi
      isMobile = lib.mkDefault true; # Laptops are mobile devices
      isMinimal = lib.mkDefault false; # Full desktop environment

      # Laptop secret categories (same as desktop)
      secretCategories = {
        base = lib.mkDefault true;
        desktop = lib.mkDefault true;
        network = lib.mkDefault true;
        cli = lib.mkDefault true; # Laptop users typically use CLI tools like atuin
      };
    };
  };
}
