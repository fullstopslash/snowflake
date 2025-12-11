# Minimal bootable ISO for NixOS installation and recovery
#
# Purpose: Run nixos-anywhere to install NixOS as quickly as possible
# Features:
#   - SSH access with authorized keys
#   - Avahi/mDNS for network discovery (mitosis.local)
#   - Pre-populated bash history with common commands
#   - Embedded nix-config for offline installation
#   - Passwordless sudo for bootstrap
#
# Build: nix build .#nixosConfigurations.iso.config.system.build.isoImage
# Usage: Boot ISO, then from workstation run: just install <hostname>
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
  ];

  # Minimal hostSpec - just what's needed for SSH keys
  hostSpec = {
    hostName = "mitosis"; # Discoverable via mitosis.local
    primaryUsername = "nixos"; # Standard installer username
    hasSecrets = false;
    inherit (inputs.nix-secrets) networking;
  };

  # SSH access for remote installation
  users.users.root.openssh.authorizedKeys.keys = [
    inputs.nix-secrets.bootstrap.sshPublicKey
  ];
  users.users.nixos.openssh.authorizedKeys.keys = [
    inputs.nix-secrets.bootstrap.sshPublicKey
  ];

  environment.etc = {
    # Pre-populate bash history with useful commands (most recent = first up-arrow)
    "skel/.bash_history" = {
      text = ''
        cat /etc/nix-config/nixos-installer/README.md
        lsblk
        ip a
        hostname  # Should show "mitosis"
        avahi-browse -a  # Browse mDNS services on network
      '';
    };
    # Pre-clone nix-config repo into ISO for offline installation
    "nix-config".source = lib.cleanSource ../../.;
  };

  # Ensure root gets the pre-populated bash history
  systemd.tmpfiles.rules = [
    "C /root/.bash_history 0600 root root - /etc/skel/.bash_history"
  ];

  # Fast compression for quick ISO builds
  isoImage.squashfsCompression = "zstd -Xcompression-level 3";

  nixpkgs = {
    hostPlatform = lib.mkDefault "x86_64-linux";
    config.allowUnfree = true;
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Passwordless sudo for bootstrap
  security.sudo.wheelNeedsPassword = false;

  services = {
    qemuGuest.enable = true;
    openssh = {
      enable = true;
      ports = [ 22 ];
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
    };
    # Avahi for mDNS - makes ISO discoverable as mitosis.local
    avahi = {
      enable = true;
      nssmdns4 = true; # Enable mDNS resolution
      publish = {
        enable = true;
        addresses = true; # Publish IP addresses
        workstation = true;
      };
    };
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = lib.mkForce [
      "btrfs"
      "vfat"
    ];
  };

  # Hostname and network auto-configuration
  networking = {
    hostName = "mitosis";
    # NetworkManager auto-connects to available networks
    networkmanager.enable = true;
    # Disable conflicting wireless config
    wireless.enable = lib.mkForce false;
  };

  systemd = {
    services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];
    targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };
  };

  # Minimal packages for troubleshooting
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    wget
    rsync
  ];

  system.stateVersion = "25.05";
}
