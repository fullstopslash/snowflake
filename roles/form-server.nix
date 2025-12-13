# Server role - headless production server
#
# Enables: SSH, firewall, CLI tools, networking, security
# Disables: GUI, audio
# Sets: isProduction, no Wayland hostSpec values
# Secret categories: base, server, network
{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  # Server-specific config
  config = lib.mkIf cfg.server {
    # Server defaults
    services.openssh.enable = lib.mkDefault true;
    networking.firewall.enable = lib.mkDefault true;

    # Enable auto-upgrade for production servers
    myModules.services.autoUpgrade.enable = lib.mkDefault true;

    # Enable CLI tools for server admin
    myModules.services.atuin.enable = lib.mkDefault true;
    myModules.networking.ssh.enable = lib.mkDefault true;

    # No GUI
    services.xserver.enable = lib.mkDefault false;

    # Server hostSpec defaults - hosts can override with lib.mkForce
    hostSpec = {
      # Behavioral defaults specific to server
      useWayland = lib.mkDefault false; # Servers are headless
      useWindowManager = lib.mkDefault false; # No GUI
      isProduction = lib.mkDefault true; # Servers are production by default
      isDevelopment = lib.mkDefault false; # Not a dev workstation
      isMobile = lib.mkDefault false; # Servers are stationary
      isMinimal = lib.mkDefault false; # Full server stack (not minimal)
      wifi = lib.mkDefault false; # Servers use ethernet

      # Server secret categories
      secretCategories = {
        base = lib.mkDefault true;
        server = lib.mkDefault true;
        network = lib.mkDefault true;
        cli = lib.mkDefault true; # CLI tools for server admin
      };
    };
  };
}
