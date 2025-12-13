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
  # Laptop-specific config
  config = lib.mkIf cfg.laptop {
    # Enable desktop modules (same as desktop role)
    myModules.desktop.plasma.enable = lib.mkDefault true;
    myModules.desktop.hyprland.enable = lib.mkDefault true;
    myModules.desktop.wayland.enable = lib.mkDefault true;
    myModules.apps.media.enable = lib.mkDefault true;

    # Display manager - LY by default (can be disabled in host config)
    myModules.displayManager.ly.enable = lib.mkDefault true;

    # Enable CLI tools for laptop users
    myModules.services.atuin.enable = lib.mkDefault true;
    myModules.networking.ssh.enable = lib.mkDefault true;
    myModules.apps.cli.tools.enable = lib.mkDefault true;
    myModules.apps.cli.shell.enable = lib.mkDefault true;

    # Enable full desktop software stack
    myModules.apps.gaming.enable = lib.mkDefault true;
    myModules.apps.development.latex.enable = lib.mkDefault true;
    myModules.apps.development.documentProcessing.enable = lib.mkDefault true;
    myModules.services.development.containers.enable = lib.mkDefault true;

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
