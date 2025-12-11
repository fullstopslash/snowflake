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
    (lib.custom.relativeToRoot "modules/common/host-spec.nix")
  ];

  hostSpec = {
    isMinimal = lib.mkForce true;
    hostName = "installer";
    username = lib.mkDefault "rain";
    primaryUsername = lib.mkDefault "rain";
  };

  # Minimal user setup - no sops, no home-manager
  users = {
    mutableUsers = false;
    users.${config.hostSpec.username} = {
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
  ];

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
