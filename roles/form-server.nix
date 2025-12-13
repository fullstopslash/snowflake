# Server role - headless production server
#
# Enables: SSH, firewall, CLI tools, auto-upgrade
# Uses unified module selection - headless by default
# Secret categories: base, server, network
{ config, lib, ... }:
{
  config = lib.mkIf (builtins.elem "server" config.roles) {
    # ========================================
    # MODULE SELECTIONS (headless)
    # ========================================
    # Paths mirror filesystem: modules/<top>/<category> = [ "<module>" ]
    modules = {
      apps = {
        cli = [
          "shell"
          "tools"
        ];
      };
      services = {
        cli = [ "atuin" ];
        networking = [
          "ssh"
          "openssh"
        ];
      };
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
