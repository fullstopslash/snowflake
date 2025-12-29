# Universal baseline configuration that ALL roles inherit
# This file contains config that every host gets regardless of role
#
# Hosts get this automatically when ANY role is enabled via roles/default.nix
# Individual roles (desktop, server, etc.) extend this with role-specific config
#
# Note: Universal settings (host, zsh, overlays) are in modules/common/universal.nix
# Note: Home-manager settings are here since this is where the module gets imported
{
  config,
  inputs,
  lib,
  ...
}:
let
  # Check if any role is enabled (roles is now a list)
  anyRoleEnabled = config.roles != [ ];
in
{
  # Core modules that all role-based hosts need
  imports = [
    # Home Manager (unstable - all hosts use the same version)
    inputs.home-manager-unstable.nixosModules.home-manager
    (lib.custom.relativeToRoot "home-manager") # Home-manager system integration

    (lib.custom.relativeToRoot "modules/common") # Includes universal.nix, sops.nix, nix.nix
    (lib.custom.relativeToRoot "modules/selection.nix") # Unified module selection system
    (lib.custom.relativeToRoot "modules/disks") # Disk configuration (disko)
    (lib.custom.relativeToRoot "modules/services") # Service modules (ssh, atuin, tailscale, etc.)
    (lib.custom.relativeToRoot "modules/apps") # Application modules (media, gaming, development, etc.)
    (lib.custom.relativeToRoot "modules/security") # Security modules (sops-enforcement, etc.)
    (lib.custom.relativeToRoot "modules/theming") # Theming modules (stylix, etc.)
    (lib.custom.relativeToRoot "modules/users")

    # nix-index for comma
    inputs.nix-index-database.nixosModules.nix-index
  ];

  # Use mkMerge to combine unconditional and conditional config
  config = lib.mkMerge [
    # Conditional: Role-specific config that extends universal settings
    (lib.mkIf anyRoleEnabled {
      #
      # ========== Role-specific host defaults ==========
      # These extend the universal defaults in modules/common/universal.nix
      #
      host = {
        # Identity defaults
        primaryUsername = lib.mkDefault "rain";
        handle = lib.mkDefault "fullstopslash";

        # Universal behavioral defaults
        # Note: isProduction is set per hardware role (server/pi=true, vm=false)
        hasSecrets = lib.mkDefault true;
        useAtticCache = lib.mkDefault true;

        # Secret categories - base is always enabled, roles add more
        secretCategories = {
          base = lib.mkDefault true;
        };
      };

    })
  ];
}
