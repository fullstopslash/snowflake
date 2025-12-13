# Template: Minimal Host Configuration Pattern
#
# This template demonstrates the minimal pattern for host configurations.
# A host config should be ~15-30 lines: hardware-configuration.nix import,
# role selection, hostname, and any hardware-specific quirks.
#
# WHAT GOES IN A HOST CONFIG:
#   1. Hardware configuration (hardware-configuration.nix, disk config)
#   2. Role selection (roles.desktop, roles.laptop, etc.)
#   3. Identity (hostSpec.hostName)
#   4. Hardware quirks (boot loader, kernel modules, etc.)
#   5. system.stateVersion
#
# WHAT COMES FROM ROLES:
#   - All imports (modules, services, apps)
#   - All behavioral hostSpec values (useWayland, isDevelopment, etc.)
#   - All service configurations
#   - All package lists
#
# OVERRIDE PATTERN:
#   Roles use lib.mkDefault, so you can override with lib.mkForce if needed.
#
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    # Add disk config if using disko:
    # inputs.disko.nixosModules.disko
    # (lib.custom.relativeToRoot "modules/disks/btrfs-disk.nix")
    # { _module.args = { disk = "/dev/sda"; withSwap = true; }; }
  ];

  #
  # ========== Role Selection ==========
  # Choose ONE hardware role + optional task roles
  #
  # Hardware roles (pick ONE):
  #   roles.desktop = true;      # Full graphical workstation
  #   roles.laptop = true;       # Desktop + power management
  #   roles.server = true;       # Headless server
  #   roles.pi = true;           # Raspberry Pi
  #   roles.tablet = true;       # Touch-friendly
  #   roles.darwin = true;       # macOS
  #   roles.vm = true;           # Virtual machine (minimal)
  #
  # Task roles (composable, pick any):
  #   roles.development = true;  # Development tools
  #   roles.mediacenter = true;  # Media playback
  #
  roles.desktop = true;
  roles.development = true;

  #
  # ========== Identity ==========
  # Only hostname is required - everything else has defaults from roles
  #
  hostSpec = {
    hostName = "myhost";
    hasSecrets = false; # Template doesn't have SOPS secrets
    # Optional overrides (roles provide defaults):
    # primaryUsername = "rain";
    # useWayland = true;
  };

  # Disk config (template uses disko)
  disks = {
    enable = true;
    layout = "btrfs";
    device = "/dev/sda";
    withSwap = false;
  };

  #
  # ========== Hardware Quirks ==========
  # Only hardware-specific settings that can't be auto-detected
  #
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # Optional: hardware-specific kernel modules, boot params, etc.
  # boot.initrd.kernelModules = [ "nvme" ];
  # boot.kernelParams = [ "quiet" ];

  #
  # ========== State Version ==========
  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  #
  system.stateVersion = "25.05";
}
