# Role System Entry Point
#
# This module is imported by the flake for all hosts that use the role system.
# It provides:
#   1. List-based role selection with LSP autocompletion via lib.types.enum
#   2. Mutual exclusivity assertion for form factor roles
#   3. Common baseline config (via common.nix) that all roles inherit
#   4. Form-factor roles (form-*): mutually exclusive, one per host
#   5. Task-based roles (task-*): composable, can combine with form factor roles
#
# Usage in host config:
#   roles = [ "desktop" "development" ];  # Form factor + task roles
#
# File naming convention:
#   form-*.nix  = Form factor roles (desktop, laptop, server, pi, tablet, darwin, vm)
#   task-*.nix  = Task roles (development, mediacenter)
#
# Roles use lib.mkDefault so hosts can override any value with lib.mkForce
{ config, lib, ... }:
let
  cfg = config.roles;

  # All available roles for enum autocompletion
  formFactorRoles = [
    "desktop"
    "laptop"
    "server"
    "pi"
    "tablet"
    "darwin"
    "vm"
  ];

  taskRoles = [
    "development"
    "fastTest"
    "mediacenter"
    "test"
  ];

  allRoles = formFactorRoles ++ taskRoles;

  # Helper to check if a role is enabled
  hasRole = role: builtins.elem role cfg;

  # Count how many form factor roles are enabled
  formFactorCount = lib.count hasRole formFactorRoles;
in
{
  imports = [
    # Universal baseline - applies when ANY role is enabled
    ./common.nix

    # Form-factor roles (mutually exclusive)
    ./form-darwin.nix
    ./form-desktop.nix
    ./form-laptop.nix
    ./form-pi.nix
    ./form-server.nix
    ./form-tablet.nix
    ./form-vm.nix

    # Task-based roles (composable)
    ./task-development.nix
    ./task-fast-test.nix
    ./task-mediacenter.nix
    ./task-test.nix
  ];

  # List-based role selection with LSP autocompletion
  options.roles = lib.mkOption {
    type = lib.types.listOf (lib.types.enum allRoles);
    default = [ ];
    description = ''
      List of roles to enable for this host.

      Form-factor roles (pick ONE):
        desktop, laptop, server, pi, tablet, darwin, vm

      Task roles (composable, pick any):
        development, fastTest, mediacenter, test

      Example: roles = [ "desktop" "development" ];
    '';
    example = [
      "vm"
      "test"
    ];
  };

  # Assertions to prevent conflicting form-factor roles
  config.assertions = [
    {
      assertion = formFactorCount <= 1;
      message = "Only one form-factor role can be enabled at a time (desktop, laptop, server, pi, tablet, darwin, vm). You have ${toString formFactorCount} enabled: ${toString (builtins.filter hasRole formFactorRoles)}";
    }
  ];
}
