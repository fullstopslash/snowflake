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

  # Disable SOPS - ISO doesn't use secrets
  myModules.security.sops-enforcement.enable = lib.mkForce false;
  sops.defaultSopsFile = lib.mkForce /dev/null; # Placeholder path - ISO doesn't use secrets

  # Enable build cache - ISO should use Attic during installation
  myModules.services.buildCache.enable = true;

  # Minimal host config - just what's needed for SSH keys
  # ISO is for recovery/install - secrets bootstrapped post-install on target system
  identity = {
    hostName = "mitosis"; # Discoverable via mitosis.local
    primaryUsername = "nixos"; # Standard installer username
    # ISO doesn't use SOPS secrets - bootstrapped post-install on target system
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
        install-host
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

  # Minimal packages for troubleshooting and installation
  environment.systemPackages = with pkgs; [
    # Version control and networking tools
    git
    vim
    neovim
    curl
    wget
    rsync
    # Filesystem tools for recovery
    btrfs-progs
    bcachefs-tools
    # Just for accessing justfile commands
    just
    # Install helper script
    (writeShellScriptBin "install-host" ''
      #!/usr/bin/env bash
      set -euo pipefail

      HOSTNAME="''${1:-}"
      if [ -z "$HOSTNAME" ]; then
        echo "Usage: install-host <hostname>"
        echo "Available hosts:"
        # shellcheck disable=SC2010
        ls /etc/nix-config/hosts/ | grep -v TEMPLATE | grep -v template | grep -v iso
        exit 1
      fi

      echo "Installing host: $HOSTNAME"
      echo "This will:"
      echo "  1. Partition and format disks with disko"
      echo "  2. Install NixOS configuration"
      echo "  3. Reboot (secrets must be bootstrapped after first boot)"
      echo ""
      read -p "Continue? (y/N) " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
      fi

      nixos-install --flake "/etc/nix-config#''${HOSTNAME}" --no-root-password

      echo ""
      echo "Installation complete!"
      echo "After reboot, run: /path/to/nix-config/scripts/bootstrap-secrets.sh $HOSTNAME"
    '')
  ];

  # Note: system.stateVersion inherited from modules/common/state-version.nix (25.11)
}
