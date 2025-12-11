# NixOS-specific system defaults
#
# System-level defaults that only apply to NixOS hosts (not Darwin).
# Auto-imported via scanPaths but only activates on Linux.
#
# Contains:
# - Terminal emulator terminfo
# - Redistributable firmware
#
# Note: User-related settings (sudo, profile dirs) are in modules/users/nixos-defaults.nix
# Note: Nix settings are in nix-management.nix
{
  lib,
  pkgs,
  ...
}:
lib.mkIf pkgs.stdenv.isLinux {
  # Add terminal emulator terminfo
  environment.systemPackages = [
    pkgs.kitty.terminfo
    pkgs.ghostty.terminfo
  ];

  # Enable firmware with a license allowing redistribution
  hardware.enableRedistributableFirmware = true;
}
