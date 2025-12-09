{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  # Server - headless, no GUI
  imports = [
    ../modules/apps/cli
    ../modules/services/networking
    ../modules/services/security
  ];

  # Server-specific config
  config = lib.mkIf cfg.server {
    # Server defaults
    services.openssh.enable = lib.mkDefault true;
    networking.firewall.enable = lib.mkDefault true;

    # No GUI
    services.xserver.enable = lib.mkDefault false;
    sound.enable = lib.mkDefault false;

    # Server hostSpec defaults - hosts can override with lib.mkForce
    hostSpec = {
      useWayland = lib.mkDefault false;
      useWindowManager = lib.mkDefault false;
      isProduction = lib.mkDefault true;
      # Server secret categories
      secretCategories = {
        base = lib.mkDefault true;
        server = lib.mkDefault true;
        network = lib.mkDefault true;
      };
    };
  };
}
