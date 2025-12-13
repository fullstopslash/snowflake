# Server role - headless production server
#
# Enables: SSH, firewall, CLI tools, auto-upgrade
# Uses unified module selection - headless by default
# Secret categories: base, server, network
{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  config = lib.mkIf cfg.server {
    # ========================================
    # MODULE SELECTIONS (headless)
    # ========================================
    modules = {
      desktop = lib.mkDefault [ ];
      displayManager = lib.mkDefault [ ];
      apps = lib.mkDefault [ ];
      cli = lib.mkDefault [ "shell" "tools" ];
      development = lib.mkDefault [ ];
      services = lib.mkDefault [ "atuin" "ssh" "openssh" "auto-upgrade" ];
      audio = lib.mkDefault [ ];
    };

    # ========================================
    # SYSTEM DEFAULTS
    # ========================================
    services.openssh.enable = lib.mkDefault true;
    networking.firewall.enable = lib.mkDefault true;
    services.xserver.enable = lib.mkDefault false;

    # ========================================
    # HOSTSPEC (non-derived options only)
    # ========================================
    hostSpec = {
      isProduction = lib.mkDefault true;
      wifi = lib.mkDefault false;

      secretCategories = {
        base = lib.mkDefault true;
        server = lib.mkDefault true;
        network = lib.mkDefault true;
        cli = lib.mkDefault true;
      };
    };
  };
}
