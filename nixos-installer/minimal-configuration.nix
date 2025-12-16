# Minimal NixOS configuration for nixos-anywhere bootstrap
#
# Purpose: Provide just enough to boot, SSH in, and run nixos-rebuild
# This is NOT meant for daily use - just for initial system installation
#
# Features:
#   - SSH access with key authentication
#   - Passwordless sudo for bootstrap
#   - Basic tools (git, curl, rsync)
#   - systemd-boot with LUKS support
#
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    (lib.custom.relativeToRoot "modules/common/host.nix")
  ];

  host = {
    isMinimal = lib.mkForce true;
    hostName = "installer";
    username = lib.mkDefault "rain";
    primaryUsername = lib.mkDefault "rain";
  };

  # Minimal user setup - no sops, no home-manager
  users = {
    mutableUsers = false;
    users.${config.host.username} = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
      ];
      # Empty password for console access during troubleshooting
      initialPassword = "";
      openssh.authorizedKeys.keys = [
        inputs.nix-secrets.bootstrap.sshPublicKey
      ];
    };
    users.root = {
      initialPassword = "";
      openssh.authorizedKeys.keys = [
        inputs.nix-secrets.bootstrap.sshPublicKey
      ];
    };
  };

  # Boot configuration
  fileSystems."/boot".options = [ "umask=0077" ];
  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        configurationLimit = lib.mkDefault 3;
        consoleMode = lib.mkDefault "max";
      };
    };
    initrd = {
      systemd.enable = true;
      systemd.emergencyAccess = true;
      luks.forceLuksSupportInInitrd = true;
    };
    kernelParams = [
      "systemd.setenv=SYSTEMD_SULOGIN_FORCE=1"
      "systemd.show_status=true"
      "systemd.log_target=console"
      "systemd.journald.forward_to_console=1"
    ];
  };

  # Minimal packages for bootstrap and troubleshooting
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    rsync
    vim
    neovim
    btrfs-progs
    bcachefs-tools
    # Install helper script
    (pkgs.writeScriptBin "install-host" ''
      #!/usr/bin/env bash
      set -euo pipefail

      HOSTNAME="''${1:-}"
      if [ -z "$HOSTNAME" ]; then
        echo "Usage: install-host <hostname>"
        echo "Available hosts:"
        # shellcheck disable=SC2010
        ls /etc/nixos-config/hosts/ | grep -v TEMPLATE | grep -v template | grep -v iso
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

      nixos-install --flake "/etc/nixos-config#''${HOSTNAME}" --no-root-password

      echo ""
      echo "Installation complete!"
      echo "After reboot, run: /path/to/nix-config/scripts/bootstrap-secrets.sh $HOSTNAME"
    '')
  ];

  # Add install-host to bash history for convenience
  environment.etc."skel/.bash_history".text = ''
    install-host
  '';

  networking.networkmanager.enable = true;

  # Passwordless sudo for wheel group during bootstrap
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
  };

  nix = {
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
    };
  };

  system.stateVersion = "25.05";
}
