# State Version Management - REFERENCE FILE
#
# NOTE: The actual stateVersion configuration is defined inline in flake.nix
# (must load before modules/users which is imported via roles/common).
#
# This file is kept for documentation purposes only.
#
# ============================================================================
# DOCUMENTATION
# ============================================================================
#
# Centralized configuration for system.stateVersion and home.stateVersion
#
# IMPORTANT: stateVersion determines compatibility settings for stateful services.
# DO NOT CHANGE on existing systems - it must match the NixOS version at install time.
#
# Current default: 25.11 (NixOS 25.11 release)
#
# Override in host config only if system was installed with older NixOS release:
#   stateVersions.system = lib.mkForce "24.05";
#   stateVersions.home = lib.mkForce "24.05";
#
# For detailed documentation, see: docs/state-version.md
#
# ============================================================================
# ACTUAL IMPLEMENTATION (for reference)
# ============================================================================
#
# The actual module is defined in flake.nix:
#
# {
#   options.stateVersions = {
#     system = lib.mkOption {
#       type = lib.types.str;
#       default = "25.11";
#       description = "NixOS state version (DO NOT CHANGE on existing systems)";
#     };
#     home = lib.mkOption {
#       type = lib.types.str;
#       default = "25.11";
#       description = "Home Manager state version (DO NOT CHANGE on existing environments)";
#     };
#   };
#
#   config = {
#     system.stateVersion = lib.mkDefault config.stateVersions.system;
#     warnings = lib.optional (
#       config.stateVersions.system != config.stateVersions.home
#     ) "StateVersion mismatch: system=${config.stateVersions.system} home=${config.stateVersions.home}";
#   };
# }
#
# ============================================================================
# UPDATING TO NEW RELEASES
# ============================================================================
#
# When a new NixOS release comes out:
#   1. Update the default values in flake.nix (lines 83 and 88)
#   2. Update this documentation to reflect the new version
#   3. Existing hosts keep their original version (DO NOT change)
#
# ============================================================================
{}
