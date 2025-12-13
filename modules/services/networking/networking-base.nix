# Networking base module
#
# Usage: modules.services.networking = [ "networking-base" ]
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.services.networking.networkingBase;
in
{
  options.myModules.services.networking.networkingBase = {
    enable = lib.mkEnableOption "Base networking configuration";
  };

  config = lib.mkIf cfg.enable {
    # Network packages
    environment.systemPackages = with pkgs; [
      wireguard-tools
      ethtool
      networkd-dispatcher
      wol
      wakeonlan
    ];

    # Network management - optimized for faster boot
    networking = {
      networkmanager = {
        enable = true;
        dns = "systemd-resolved";
      };
      firewall = {
        enable = true;
        allowedTCPPorts = [
          10400
          10700
        ];
        allowedUDPPorts = [ 41641 ];
      };
    };

    # Core network services
    services = {
      avahi = {
        enable = true;
        nssmdns4 = true;
        publish = {
          enable = true;
          addresses = true;
          domain = true;
          hinfo = true;
          userServices = true;
          workstation = true;
        };
        allowInterfaces = [ "tailscale0" ]; # optimized startup
      };
      resolved = {
        enable = true;
        dnssec = "allow-downgrade";
      };
    };
  };
}
