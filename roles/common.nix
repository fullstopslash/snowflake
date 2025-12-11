# Universal baseline configuration that ALL roles inherit
# This file contains config that every host gets regardless of role
#
# Hosts get this automatically when ANY role is enabled via roles/default.nix
# Individual roles (desktop, server, etc.) extend this with role-specific config
#
# Note: Universal settings (hostSpec, zsh, overlays) are in modules/common/universal.nix
# Note: Home-manager settings are here since this is where the module gets imported
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.roles;
  # Check if any hardware role is enabled
  anyRoleEnabled =
    cfg.desktop || cfg.laptop || cfg.server || cfg.pi || cfg.tablet || cfg.darwin || cfg.vm;
in
{
  # Core modules that all role-based hosts need
  imports = [
    # Home Manager (unstable - all hosts use the same version)
    inputs.home-manager-unstable.nixosModules.home-manager

    (lib.custom.relativeToRoot "modules/common") # Includes universal.nix, sops.nix, nix.nix
    (lib.custom.relativeToRoot "modules/disks") # Disk configuration (disko)
    (lib.custom.relativeToRoot "modules/services") # Service modules (ssh, atuin, tailscale, etc.)
    (lib.custom.relativeToRoot "modules/users")

    # nix-index for comma
    inputs.nix-index-database.nixosModules.nix-index
  ];

  # Use mkMerge to combine unconditional and conditional config
  config = lib.mkMerge [
    # Unconditional: Home-manager defaults (always set since module is imported above)
    {
      home-manager = {
        useGlobalPkgs = lib.mkDefault true;
        backupFileExtension = lib.mkDefault "bk";
        extraSpecialArgs = lib.mkDefault {
          inherit inputs;
          hostSpec = config.hostSpec;
        };
      };
    }

    # Conditional: Role-specific config that extends universal settings
    (lib.mkIf anyRoleEnabled {
      #
      # ========== Role-specific hostSpec defaults ==========
      # These extend the universal defaults in modules/common/universal.nix
      #
      hostSpec = {
        # Universal behavioral defaults (all production hosts)
        isProduction = lib.mkDefault true;
        hasSecrets = lib.mkDefault true;
        useAtticCache = lib.mkDefault true;

        # Secret categories - base is always enabled, roles add more
        secretCategories = {
          base = lib.mkDefault true;
        };
      };

      #
      # ========== NixOS-specific settings ==========
      #
      # Latest stable NixOS version - hosts can override if needed
      system.stateVersion = lib.mkDefault "25.05";

      # Enable comma for nix-index-database
      programs.nix-index-database.comma.enable = lib.mkDefault true;
    })
  ];
}
