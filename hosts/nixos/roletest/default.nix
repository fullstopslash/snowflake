{ lib, ... }:
{
  imports = [
    # Core modules required for all hosts
    (lib.custom.relativeToRoot "hosts/common/core")
  ];

  # Minimal host using role system
  roles.vm = true; # Use VM role for testing

  # Required host-specific settings
  hostSpec = {
    hostName = "roletest";
    primaryUsername = "test";
  };

  # Minimal hardware (for evaluation only)
  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };
  boot.loader.grub.device = "/dev/sda";

  system.stateVersion = "25.05";
}
