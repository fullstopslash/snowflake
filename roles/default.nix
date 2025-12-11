# Role System Entry Point
#
# This module is imported by the flake for all hosts that use the role system.
# It provides:
#   1. Role option definitions (options.roles.*)
#   2. Mutual exclusivity assertion for hardware roles
#   3. Common baseline config (via common.nix) that all roles inherit
#   4. Hardware-based roles (hw-*): mutually exclusive, one per host
#   5. Task-based roles (task-*): composable, can combine with hardware roles
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
{ config, lib, ... }:
let
  cfg = config.roles;
in
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
    ./task-secret-management.nix
    ./task-test.nix
    ./task-vm-hardware.nix
  ];

  options.roles = {
    # Hardware-based roles (mutually exclusive - only one can be enabled)
    desktop = lib.mkEnableOption "Desktop workstation role";
    laptop = lib.mkEnableOption "Laptop role (desktop + power management)";
    server = lib.mkEnableOption "Headless server role";
    pi = lib.mkEnableOption "Raspberry Pi role";
    tablet = lib.mkEnableOption "Tablet role (touch-friendly)";
    darwin = lib.mkEnableOption "macOS/Darwin role";
    vm = lib.mkEnableOption "Virtual machine role";

    # Task-based roles (composable - can be combined with hardware roles)
    development = lib.mkEnableOption "Development environment (IDEs, LSPs, dev tools)";
    mediacenter = lib.mkEnableOption "Media center role (media playback, streaming clients)";
    test = lib.mkEnableOption "Test/development VM settings (passwordless sudo, SSH password auth)";
    vmHardware = lib.mkEnableOption "VM hardware (QEMU guest, virtio, boot config) - composable with any hardware role";
  };

  # Assertions to prevent conflicting hardware roles
  config.assertions = [
    {
      assertion =
        lib.count (x: x) [
          cfg.desktop
          cfg.laptop
          cfg.server
          cfg.pi
          cfg.tablet
          cfg.darwin
          cfg.vm
        ] <= 1;
      message = "Only one hardware role can be enabled at a time (desktop, laptop, server, pi, tablet, darwin, vm)";
    }
  ];
}
