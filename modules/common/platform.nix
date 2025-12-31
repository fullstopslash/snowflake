# Platform Configuration Module
#
# Defines core system platform properties needed for cross-platform support.
# This module handles architecture detection and nixpkgs variant selection.
#
# Options:
# - system.architecture: System architecture (x86_64-linux, aarch64-linux, etc.)
# - system.nixpkgsVariant: Which nixpkgs to use (stable/unstable)
# - system.useCustomPkgs: Whether to use alternate nixpkgs (computed)
# - system.isDarwin: Platform detection flag
#
    # CONCURRENT TEST: Change from griefling at 2025-12-31 12:58:00
{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.system = {
    architecture = lib.mkOption {
      type = lib.types.str;
      description = "System architecture (x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin)";
      example = "x86_64-linux";
    };

    nixpkgsVariant = lib.mkOption {
      type = lib.types.enum [
        "stable"
        "unstable"
      ];
      default = "stable";
      description = "Which nixpkgs input to use (stable or unstable)";
    };

    useCustomPkgs = lib.mkOption {
      type = lib.types.bool;
      default = config.system.nixpkgsVariant != "stable";
      description = "Whether to use alternate nixpkgs with custom config (derived from nixpkgsVariant)";
      readOnly = true;
    };

    isDarwin = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Darwin platform flag (set to true for macOS hosts)";
    };
  };
}
