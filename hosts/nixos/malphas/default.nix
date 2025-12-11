# Malphas - VM Test Host
#
# A minimal QEMU VM for testing the role-based configuration system.
# Uses roles.vm for minimal configuration without desktop overhead.
#
{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    (lib.custom.relativeToRoot "hosts/common/core")
  ];

  # Minimal VM role
  roles.vm = true;

  hostSpec = {
    hostName = "malphas";
    hasSecrets = false; # VM doesn't have real secrets
  };

  # VM-specific boot configuration
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  boot.initrd.systemd.enable = true;

  # Networking
  networking.networkmanager.enable = true;

  # SSH for test VM
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };

  system.stateVersion = "25.05";
}
