# Malphas - Primary Desktop Workstation
#
# Main development machine with audio production capabilities.
#
{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./audio-tuning.nix
  ];

  # Roles: minimal VM + test settings
  roles = [
    "vm"
    "test"
  ];

  # Disk configuration
  disks = {
    enable = true;
    layout = "btrfs";
    device = "/dev/vda";
    withSwap = false;
  };

  # Identity
  host = {
    hostName = "malphas";
    hasSecrets = true; # Enabled for dotfiles secrets (acoustid_api)
  };

  # ========================================
  # STATE VERSION (explicit for physical hosts)
  # ========================================
  # Malphas will be deployed with NixOS 25.11
  # This setting must NEVER change after deployment
  stateVersions.system = lib.mkForce "25.11";
  stateVersions.home = lib.mkForce "25.11";
}
