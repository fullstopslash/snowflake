# Malphas - Minimal VM Test Host
#
# A minimal QEMU VM for testing the role-based configuration system.
# Core modules come from roles/common.nix; disk config via modules/disks.
#
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  # Roles: minimal VM + test settings
  roles.vm = true;
  roles.test = true;

  # Disk configuration
  disks = {
    enable = true;
    layout = "btrfs";
    device = "/dev/vda";
    withSwap = false;
  };

  # Identity
  hostSpec = {
    hostName = "malphas";
    hasSecrets = false;
  };
}
