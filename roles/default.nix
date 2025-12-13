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
#   form-*.nix  = Form factor roles (mutually exclusive)
#   task-*.nix  = Task roles (composable)
#
# To add a new role: just create form-<name>.nix or task-<name>.nix
# The role system auto-discovers files and generates options.
#
# Roles use lib.mkDefault so hosts can override any value with lib.mkForce
{ config, lib, ... }:
let
  cfg = config.roles;

  # Scan directory for role files
  allFiles = builtins.attrNames (builtins.readDir ./.);

  # Convert kebab-case to camelCase: "fast-test" -> "fastTest"
  kebabToCamel = str:
    let
      parts = lib.splitString "-" str;
      capitalize = s:
        if s == "" then ""
        else lib.toUpper (lib.substring 0 1 s) + lib.substring 1 (-1) s;
    in
    lib.head parts + lib.concatStrings (map capitalize (lib.tail parts));

  # Extract role names from files matching prefix
  # "form-desktop.nix" -> "desktop", "task-fast-test.nix" -> "fastTest"
  extractRoles = prefix:
    lib.pipe allFiles [
      (builtins.filter (name: lib.hasPrefix prefix name && lib.hasSuffix ".nix" name))
      (map (name: kebabToCamel (lib.removeSuffix ".nix" (lib.removePrefix prefix name))))
    ];

  # Auto-discover role lists from filesystem
  formFactorRoles = extractRoles "form-";
  taskRoles = extractRoles "task-";
  allRoles = formFactorRoles ++ taskRoles;

  # Auto-discover role file imports
  roleImports = lib.pipe allFiles [
    (builtins.filter (name:
      (lib.hasPrefix "form-" name || lib.hasPrefix "task-" name)
      && lib.hasSuffix ".nix" name))
    (map (name: ./${name}))
  ];

  # Helper to check if a role is enabled
  hasRole = role: builtins.elem role cfg;

  # Count how many form factor roles are enabled
  formFactorCount = lib.count hasRole formFactorRoles;
in
{
  # Universal baseline + auto-discovered role files
  imports = [ ./common.nix ] ++ roleImports;

  # List-based role selection with LSP autocompletion
  options.roles = lib.mkOption {
    type = lib.types.listOf (lib.types.enum allRoles);
    default = [ ];
    description = ''
      List of roles to enable for this host.

      Form-factor roles (pick ONE): ${lib.concatStringsSep ", " formFactorRoles}

      Task roles (composable, pick any): ${lib.concatStringsSep ", " taskRoles}

      Example: roles = [ "desktop" "development" ];
    '';
    example = [ "vm" "test" ];
  };

  # Assertions to prevent conflicting form-factor roles
  config.assertions = [
    {
      assertion = formFactorCount <= 1;
      message = "Only one form-factor role can be enabled at a time (${lib.concatStringsSep ", " formFactorRoles}). You have ${toString formFactorCount} enabled: ${toString (builtins.filter hasRole formFactorRoles)}";
    }
  ];
}
