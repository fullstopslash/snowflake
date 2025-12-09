# Malphas - VM Test Host
#
# A minimal QEMU VM for testing the role-based configuration system.
# Uses roles.vm for minimal configuration without desktop overhead.
#
{
  lib,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    (lib.custom.relativeToRoot "hosts/common/core")
  ];

  # VM role - minimal configuration for testing
  roles.vm = true;

  hostSpec = {
    hostName = "malphas";
    # VM doesn't have real secrets - use fixture or disable
    hasSecrets = false;
  };

  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    timeout = 3;
  };

  boot.initrd.systemd.enable = true;

  system.stateVersion = "25.05";
}
