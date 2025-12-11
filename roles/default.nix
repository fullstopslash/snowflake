# Role System Entry Point
#
# This module is imported by the flake for all hosts that use the role system.
# It provides:
#   1. Common baseline config (via common.nix) that all roles inherit
#   2. Hardware-based roles (hw-*): mutually exclusive, one per host
#   3. Task-based roles (task-*): composable, can combine with hardware roles
#
# Usage in host config:
#   roles.desktop = true;      # Hardware role
#   roles.development = true;  # Task role (composable with hardware roles)
#
# File naming convention:
#   hw-*.nix    = Hardware roles (desktop, laptop, server, pi, tablet, darwin, vm)
#   task-*.nix  = Task roles (development, mediacenter)
#
# Roles use lib.mkDefault so hosts can override any value with lib.mkForce
{ ... }:
{
  imports = [
    # Universal baseline - applies when ANY role is enabled
    ./common.nix

    # Hardware-based roles (mutually exclusive)
    ./hw-darwin.nix
    ./hw-desktop.nix
    ./hw-laptop.nix
    ./hw-pi.nix
    ./hw-server.nix
    ./hw-tablet.nix
    ./hw-vm.nix

    # Task-based roles (composable)
    ./task-development.nix
    ./task-mediacenter.nix
    ./task-test.nix
    ./task-vm-hardware.nix
  ];
}
