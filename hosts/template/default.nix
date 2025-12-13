# Template: Minimal Host Configuration Pattern
#
# This template demonstrates the minimal pattern for host configurations.
# A host config should be ~15-30 lines: hardware-configuration.nix import,
# role selection, hostname, and any hardware-specific quirks.
#
# WHAT GOES IN A HOST CONFIG:
#   1. Hardware configuration (hardware-configuration.nix, disk config)
#   2. Role selection: roles = [ "desktop" "development" ]
#   3. Identity (hostSpec.hostName)
#   4. Hardware quirks (boot loader, kernel modules, etc.)
#
# WHAT COMES FROM ROLES:
#   - All imports (modules, services, apps)
#   - All behavioral hostSpec values (useWayland, isDevelopment, etc.)
#   - All service configurations
#   - All package lists
#
# OVERRIDE PATTERN:
#   Roles use lib.mkDefault, hosts extend with extraModules.* or override with lib.mkForce.
#
{ ... }:
{
  imports = [ ./hardware-configuration.nix ];

  # ========================================
  # ROLE SELECTION (LSP autocomplete-enabled)
  # ========================================
  # Form factor: vm | desktop | laptop | server | pi | tablet | darwin
  # Task roles: development | mediacenter | test | fastTest
  roles = [
    "desktop"
    "development"
  ];

  # ========================================
  # EXTRA MODULES (additive to role defaults)
  # ========================================
  # Paths mirror filesystem: extraModules.<top>.<category> = [ "<module>" ]
  # extraModules.apps.productivity = [ "default" ];
  # extraModules.services.networking = [ "tailscale" ];

  # ========================================
  # HOST IDENTITY
  # ========================================
  hostSpec = {
    hostName = "myhost";
    hasSecrets = false; # Template doesn't have SOPS secrets
  };

  # ========================================
  # DISK CONFIGURATION
  # ========================================
  disks = {
    enable = true;
    layout = "btrfs";
    device = "/dev/sda";
    withSwap = false;
  };

  # ========================================
  # HARDWARE QUIRKS
  # ========================================
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # Note: system.stateVersion is set centrally in flake.nix
}
