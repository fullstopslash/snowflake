# Networking role
{pkgs, ...}: {
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
      allowedTCPPorts = [10400 10700];
      allowedUDPPorts = [41641];
    };
  };

  # Optional: soften DNSSEC to avoid flaky captive/Wi‑Fi resumes
  # Core network services; split others into dedicated roles
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
      allowInterfaces = ["tailscale0"]; # optimized startup
    };
    resolved = {
      enable = true;
      dnssec = "allow-downgrade";
      # dnsovertls = "true";
    };
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        AllowUsers = ["rain"];
        StreamLocalBindUnlink = true;
      };
    };
    # mullvad: roles/vpn.nix
    # tailscale: roles/tailscale.nix
    # avahi: roles/mdns.nix
  };
}
