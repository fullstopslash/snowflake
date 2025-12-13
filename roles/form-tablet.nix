# Tablet role - touch-friendly portable device
#
# Enables: Desktop, audio, CLI, fonts, media
# Enables: Touch input, power management
# Sets: isMobile, wifi hostSpec values
{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  # Tablet-specific config
  config = lib.mkIf cfg.tablet {
    # Enable desktop modules
    myModules.desktop.wayland.enable = lib.mkDefault true;
    myModules.apps.media.enable = lib.mkDefault true;
    myModules.apps.cli.shell.enable = lib.mkDefault true;

    # Touch input
    services.libinput.enable = lib.mkDefault true;

    # Power management
    powerManagement.enable = lib.mkDefault true;

    # Tablet hostSpec defaults - hosts can override with lib.mkForce
    hostSpec = {
      # Behavioral defaults specific to tablet
      isMobile = lib.mkDefault true; # Tablets are mobile devices
      wifi = lib.mkDefault true; # Tablets always have wifi
      useWayland = lib.mkDefault true; # Modern tablets use Wayland
      useWindowManager = lib.mkDefault true; # Tablets have GUI
      isDevelopment = lib.mkDefault false; # Tablets are not dev workstations
      isMinimal = lib.mkDefault false; # Full touch-friendly UI

      # Tablet secret categories
      secretCategories = {
        base = lib.mkDefault true;
        desktop = lib.mkDefault true;
        network = lib.mkDefault true;
      };
    };
  };
}
