# Host Configuration Module
#
# This module defines WHO the machine is (identity + hardware + preferences),
# not HOW it behaves (that's derived from modules/roles).
#
# Three-tier system:
# - /roles: Presets (vm, desktop, server) that configure modules + host defaults
# - /modules: Individual units of functionality (services, apps, etc.)
# - /hosts: Identity layer (this module) - what makes each host unique
#
# Option Categories:
# - IDENTITY: Host-specific values (hostName, primaryUsername, email)
# - HARDWARE: Physical capabilities (wifi, hdr, scaling)
# - PREFERENCES: User choices (theme, defaultBrowser, wallpaper)
# - DERIVED: Computed from modules.* selections - rarely need manual override
# - SECRET CATEGORIES: What secrets needed - set by roles
#
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  # Helper to check if list contains any wayland-based desktop
  hasWaylandDesktop = builtins.any (m: builtins.elem m config.modules.desktop) [
    "hyprland"
    "niri"
    "wayland"
    "plasma" # Plasma 6 is Wayland by default
  ];
in
{
  options.host = lib.mkOption {
    type = lib.types.submodule {
      freeformType = with lib.types; attrsOf str;

      options = {
        # ========================================
        # IDENTITY OPTIONS
        # ========================================
        # Host-specific identity values that each host must specify.
        # Defaults are provided by roles/common.nix for convenience.

        hostName = lib.mkOption {
          type = lib.types.str;
          description = "The hostname of the host (MUST be set by each host)";
        };

        primaryUsername = lib.mkOption {
          type = lib.types.str;
          description = "The primary username of the host (default: 'rain' from common.nix)";
        };

        # Deprecated: use primaryUsername instead. Kept for backward compatibility.
        username = lib.mkOption {
          type = lib.types.str;
          default = config.host.primaryUsername;
          description = "Deprecated: alias for primaryUsername";
        };

        email = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          description = "The email of the user (imported from nix-secrets)";
        };

        domain = lib.mkOption {
          type = lib.types.str;
          default = "local"; # Need a default for the installer
          description = "The domain of the host (imported from nix-secrets)";
        };

        userFullName = lib.mkOption {
          type = lib.types.str;
          description = "The full name of the user (imported from nix-secrets)";
        };

        handle = lib.mkOption {
          type = lib.types.str;
          description = "The handle of the user (default: 'fullstopslash' from common.nix)";
        };

        networking = lib.mkOption {
          default = { };
          type = lib.types.attrsOf lib.types.anything;
          description = "An attribute set of networking information (imported from nix-secrets)";
        };

        home = lib.mkOption {
          type = lib.types.str;
          description = "The home directory of the user (auto-computed from primaryUsername)";
          default =
            let
              user = config.host.primaryUsername;
            in
            if pkgs.stdenv.isLinux then "/home/${user}" else "/Users/${user}";
        };

        users = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "A list of all users on the host (defaults to primaryUsername)";
          default = [ config.host.primaryUsername ];
        };

        architecture = lib.mkOption {
          type = lib.types.str;
          description = "System architecture (x86_64-linux, aarch64-linux, x86_64-darwin) - set by roles";
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
          default = config.host.nixpkgsVariant != "stable";
          description = "Whether to use alternate nixpkgs with custom config (derived from nixpkgsVariant)";
        };

        # ========================================
        # HARDWARE OPTIONS
        # ========================================
        # Physical hardware capabilities.
        # Roles can set sensible defaults, but hosts override based on actual hardware.

        wifi = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Hardware has wifi capability (roles: laptop/tablet=true, desktop/server=false)";
        };

        hdr = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Display supports HDR (host sets based on actual hardware)";
        };

        scaling = lib.mkOption {
          type = lib.types.str;
          default = "1";
          description = "Display scaling factor (host sets based on DPI/preferences)";
        };

        # Sometimes we can't use pkgs.stdenv.isLinux due to infinite recursion
        isDarwin = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Used to indicate a host that is darwin (host sets based on platform)";
        };

        persistFolder = lib.mkOption {
          type = lib.types.str;
          description = "The folder to persist data if impermanence is enabled (host-specific)";
          default = "";
        };

        # ========================================
        # PREFERENCES
        # ========================================
        # User preferences that hosts can customize.

        isWork = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Host uses work resources (host decides based on usage)";
        };

        useYubikey = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Host uses Yubikey authentication (host decides)";
        };

        voiceCoding = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Host uses voice coding (Talon) (host decides)";
        };

        isAutoStyled = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Auto styling with stylix (host decides)";
        };

        theme = lib.mkOption {
          type = lib.types.str;
          default = "dracula";
          description = "Theme name (host preference)";
        };

        useNeovimTerminal = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Use neovim as terminal (host preference)";
        };

        wallpaper = lib.mkOption {
          type = lib.types.path;
          default = "${inputs.nix-assets}/images/wallpapers/zen-01.png";
          description = "Wallpaper path (host preference)";
        };

        defaultBrowser = lib.mkOption {
          type = lib.types.str;
          default = "firefox";
          description = "Default browser (host preference)";
        };

        defaultEditor = lib.mkOption {
          type = lib.types.str;
          default = "nvim";
          description = "Default editor command (host preference)";
        };

        defaultDesktop = lib.mkOption {
          type = lib.types.str;
          default = "Hyprland";
          description = "Default desktop environment (host preference)";
        };

        # ========================================
        # DERIVED OPTIONS
        # ========================================
        # Computed from modules.* selections but can be overridden with lib.mkForce.
        # Most users should never need to set these directly.

        isMinimal = lib.mkOption {
          type = lib.types.bool;
          default = config.modules.desktop == [ ] && config.modules.apps == [ ];
          description = "Minimal installation (derived: true if no desktop or apps selected)";
        };

        isHeadless = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Headless system without GUI packages (roles override: vm-headless=true)";
        };

        isProduction = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Production vs test environment (roles override: vm=false)";
        };

        isDevelopment = lib.mkOption {
          type = lib.types.bool;
          default = config.modules.development != [ ];
          description = "Development tools enabled (derived: true if any development modules selected)";
        };

        isMobile = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Mobile device (set by laptop/tablet roles based on hardware form factor)";
        };

        useWayland = lib.mkOption {
          type = lib.types.bool;
          default = hasWaylandDesktop;
          description = "Use Wayland display server (derived: true if wayland-based desktop selected)";
        };

        useWindowManager = lib.mkOption {
          type = lib.types.bool;
          default = config.modules.desktop != [ ];
          description = "Use graphical window manager (derived: true if any desktop modules selected)";
        };

        hasSecrets = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "SOPS secrets configured (roles override: vm=false)";
        };

        useAtticCache = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Use LAN atticd for binary caching (set by common.nix)";
        };

        # ========================================
        # SECRET CATEGORIES
        # ========================================
        # Roles automatically configure which secret categories a host needs.

        secretCategories = lib.mkOption {
          type = lib.types.submodule {
            options = {
              base = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Base secrets: user passwords, age keys, msmtp (all roles)";
              };
              desktop = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Desktop secrets: home assistant (desktop/laptop/tablet roles)";
              };
              server = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Server secrets: backup, service credentials (server role)";
              };
              network = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Network secrets: tailscale, VPN (desktop/laptop/tablet/server/pi roles)";
              };
              cli = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "CLI tool secrets: atuin credentials (desktop/laptop/server roles)";
              };
            };
          };
          default = { };
          description = "Secret categories enabled for this host (set by roles, hosts can override)";
        };
      };
    };
  };

  config = {
    assertions =
      let
        # We import these options to HM and NixOS, so need to not fail on HM
        isImpermanent =
          config ? "system" && config.system ? "impermanence" && config.system.impermanence.enable;
      in
      [
        {
          assertion = !config.host.isWork || (config.host.isWork && !builtins.isNull config.host.work);
          message = "isWork is true but no work attribute set is provided";
        }
        {
          assertion = !isImpermanent || (isImpermanent && !("${config.host.persistFolder}" == ""));
          message = "config.system.impermanence.enable is true but no persistFolder path is provided";
        }
        {
          assertion = !(config.host.voiceCoding && config.host.useWayland);
          message = "Talon, which is used for voice coding, does not support Wayland. See https://github.com/splondike/wayland-accessibility-notes";
        }
      ];
  };
}
