# Malphas - Primary Desktop Workstation
#
# Main development machine with audio production capabilities.
#
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./audio-tuning.nix
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
