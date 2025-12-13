# Desktop role - full graphical workstation
#
# Enables: GUI desktop environment, audio, media apps, gaming, development tools
# Sets: useWayland, useWindowManager, isDevelopment hostSpec values
# Secret categories: base, desktop, network
{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  # Config options are conditional on role being enabled
  config = lib.mkIf cfg.desktop {
    # Enable desktop modules
    myModules.desktop.plasma.enable = lib.mkDefault true;
    myModules.apps.media.enable = lib.mkDefault true;
    myModules.desktop.hyprland.enable = lib.mkDefault true;
    myModules.desktop.wayland.enable = lib.mkDefault true;
    # Desktop-specific defaults
    services.xserver.enable = lib.mkDefault true;
    hardware.graphics.enable = lib.mkDefault true;

    # Display manager - LY by default (can be disabled in host config)
    myModules.displayManager.ly.enable = lib.mkDefault true;

    # Enable CLI tools for desktop users
    myModules.services.atuin.enable = lib.mkDefault true;
    myModules.networking.ssh.enable = lib.mkDefault true;

    # Enable full desktop software stack
    myModules.apps.gaming.enable = lib.mkDefault true;
    myModules.apps.development.latex.enable = lib.mkDefault true;
    myModules.apps.development.documentProcessing.enable = lib.mkDefault true;
    myModules.services.development.containers.enable = lib.mkDefault true;
    myModules.apps.cli.tools.enable = lib.mkDefault true;
    myModules.apps.cli.shell.enable = lib.mkDefault true;

    # Desktop hostSpec defaults - hosts can override with lib.mkForce
    hostSpec = {
      # Behavioral defaults specific to desktop
      useWayland = lib.mkDefault true;
      useWindowManager = lib.mkDefault true;
      isDevelopment = lib.mkDefault true;
      isMobile = lib.mkDefault false; # Desktops are not mobile
      wifi = lib.mkDefault false; # Desktops typically use ethernet
      isMinimal = lib.mkDefault false; # Full desktop environment

      # Desktop secret categories
      secretCategories = {
        base = lib.mkDefault true;
        desktop = lib.mkDefault true;
        network = lib.mkDefault true;
        cli = lib.mkDefault true; # Desktop users typically use CLI tools like atuin
      };
    };
  };
}
