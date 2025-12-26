# Networking role
{pkgs, ...}: {
  # Network packages
  environment.systemPackages = with pkgs; [
    wireguard-tools
    ethtool
    networkd-dispatcher
    wol
    wakeonlan
    nyx
    tor
    torctl
    torsocks
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
    # IPv6 configuration
    enableIPv6 = true;
    # DNS nameservers
    nameservers = ["1.1.1.1" "1.0.0.1"];
  };

  # Kernel networking parameters
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;
    # Accept IPv6 Router Advertisements even when forwarding is enabled
    "net.ipv6.conf.all.accept_ra" = 2;
    "net.ipv6.conf.default.accept_ra" = 2;
  };

  # DNSSEC enabled: Technitium validates upstream, systemd-resolved validates locally
  # Defense-in-depth: dual validation for enhanced security
  # Core network services; split others into dedicated roles
  services = {
    # avahi = {
    #   enable = true;
    #   nssmdns4 = true;
    #   publish = {
    #     enable = true;
    #     addresses = true;
    #     domain = true;
    #     hinfo = true;
    #     userServices = true;
    #     workstation = true;
    #   };
    #   allowInterfaces = ["tailscale0"]; # optimized startup
    # };
    resolved = {
      enable = true;
      dnssec = "allow-downgrade"; # Validate DNSSEC when available, fallback if not
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
