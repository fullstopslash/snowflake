# Nix Management - Core settings for all hosts
#
# Consolidated nix configuration including:
# - Nix daemon settings (package, caches, optimisation)
# - nixpkgs configuration (allowUnfree, etc.)
# - Auto-upgrade (NixOS only)
# - nh (nix helper) for better build output
# - Flake registry and nixPath (NixOS only)
# - Config repo auto-clone service (NixOS only)
#
# This is the single source of truth for nix settings.
# All hosts get these settings for fast, consistent builds.
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  # Config repo settings
  repoCfg = config.myModules.services.nixConfigRepo;
  user = config.host.primaryUsername;
  home = config.host.home;
in
{
  #
  # ========== Options ==========
  #
  options.myModules.services.nixConfigRepo = {
    enable = lib.mkEnableOption "Auto-clone nix-config and nix-secrets repos";

    configRepoSsh = lib.mkOption {
      type = lib.types.str;
      default = "git@github.com:fullstopslash/snowflake.git";
      description = "SSH URL for nix-config repository";
    };

    configRepoHttps = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/fullstopslash/snowflake.git";
      description = "HTTPS URL for nix-config repository (fallback)";
    };

    secretsRepoSsh = lib.mkOption {
      type = lib.types.str;
      default = "git@github.com:fullstopslash/snowflake-secrets.git";
      description = "SSH URL for nix-secrets repository";
    };

    secretsRepoHttps = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/fullstopslash/snowflake-secrets.git";
      description = "HTTPS URL for nix-secrets repository (fallback)";
    };

    configBranch = lib.mkOption {
      type = lib.types.str;
      default = "dev";
      description = "Branch to checkout for nix-config";
    };

    secretsBranch = lib.mkOption {
      type = lib.types.str;
      default = "simple";
      description = "Branch to checkout for nix-secrets";
    };
  };

  #
  # ========== Configuration ==========
  #
  config = lib.mkMerge [
    #
    # ========== Base Configuration (all hosts) ==========
    #
    {
      nixpkgs.config = {
        allowBroken = true;
        allowUnfree = true;
      };

      nix = {
        # We want at least 2.30 to get the memory management improvements
        # https://discourse.nixos.org/t/nix-2-30-0-released/66449/4
        #FIXME(nix): unpin when stable catches up to 2.30+
        # Use unstable if available (via overlay), otherwise use default
        package = lib.mkDefault (
          if pkgs ? unstable && pkgs.unstable ? nixVersions then
            pkgs.unstable.nixVersions.nix_2_30
          else
            pkgs.nix
        );

        # Periodically optimize the store
        optimise = {
          automatic = true;
          dates = [ "03:45" ];
        };

        settings = {
          # See https://jackson.dev/post/nix-reasonable-defaults/
          connect-timeout = 5;
          log-lines = 25;
          min-free = 128000000; # 128MB
          max-free = 1000000000; # 1GB
          experimental-features = lib.mkDefault "nix-command flakes";
          warn-dirty = false;
          allow-import-from-derivation = true;
          trusted-users = [ "@wheel" ];
          builders-use-substitutes = true;
          fallback = true; # Don't hard fail if a binary cache isn't available, since some systems roam

          # Binary caches for faster builds
          substituters = [
            "https://cache.nixos.org" # Official global cache
            "https://nix-community.cachix.org" # Community packages
            "https://hyprland.cachix.org" # Hyprland cache
          ];
          extra-trusted-public-keys = [
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
          ];
        };

        # Access token prevents github rate limiting if you have to nix flake update a bunch
        #TODO
        #extraOptions =
        #  if config ? "sops" then "!include ${config.sops.secrets."tokens/nix-access-tokens".path}" else "";
      }
      #
      # ========== NixOS-only: Registry & nixPath ==========
      #
      // (lib.optionalAttrs pkgs.stdenv.isLinux {
        # This will add each flake input as a registry
        # To make nix3 commands consistent with your flake
        registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

        # This will add your inputs to the system's legacy channels
        # Making legacy nix commands consistent as well
        nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
      });

      #
      # ========== NixOS-only: nh (Nix Helper) ==========
      #
      # Better build output and garbage collection
      # https://github.com/viperML/nh
      programs.nh = lib.mkIf pkgs.stdenv.isLinux {
        enable = true;
        clean.enable = true;
        clean.extraArgs = "--keep-since 20d --keep 20";
        # Points to where nix-config is located
        flake = "${home}/nix-config";
      };

      #
      # ========== NixOS-only: Auto-upgrade ==========
      #
      # Auto-upgrade is now handled by myModules.services.autoUpgrade
      # See modules/services/misc/auto-upgrade.nix for configuration
      #
    }

    #
    # ========== NixOS-only: Config Repo Auto-clone ==========
    #
    # Auto-clone nix-config and nix-secrets repos for distributed management
    # This ensures each host has local clones of the config repos at:
    # - ~/nix-config - main NixOS configuration flake
    # - ~/nix-secrets - encrypted secrets repo
    # - /etc/nixos -> ~/nix-config (symlink for system compatibility)
    #
    # Clone strategy:
    # 1. Try SSH URL first (allows push access if key is configured)
    # 2. Fall back to HTTPS URL (read-only, but works without auth)
    (lib.mkIf repoCfg.enable {
      environment.etc."nixos".source = lib.mkForce "${home}/nix-config";

      systemd.user.services.nix-config-clone = {
        description = "Clone nix-config and nix-secrets repos if not present";
        wantedBy = [ "default.target" ];
        after = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        path = with pkgs; [
          git
          openssh
        ];
        script = ''
          set -eu
          echo "Checking for nix-config repos..."

          CONFIG_DIR="${home}/nix-config"
          SECRETS_DIR="${home}/nix-secrets"

          # Function to clone with SSH fallback to HTTPS
          clone_repo() {
            local dir="$1"
            local ssh_url="$2"
            local https_url="$3"
            local branch="$4"
            local name="$5"

            if [ -d "$dir" ]; then
              echo "$name already exists at $dir"
              return 0
            fi

            echo "Cloning $name to $dir..."

            # Try SSH first (allows push if key is configured)
            if git clone --branch "$branch" "$ssh_url" "$dir" 2>/dev/null; then
              echo "$name cloned via SSH successfully"
              return 0
            fi

            echo "SSH clone failed, trying HTTPS..."

            # Fall back to HTTPS (read-only but works without auth)
            if git clone --branch "$branch" "$https_url" "$dir"; then
              echo "$name cloned via HTTPS successfully"
              echo "Note: To enable push, run: git -C $dir remote set-url origin $ssh_url"
              return 0
            fi

            echo "Failed to clone $name (check network connectivity)" >&2
            return 1
          }

          # Clone nix-config
          clone_repo "$CONFIG_DIR" "${repoCfg.configRepoSsh}" "${repoCfg.configRepoHttps}" "${repoCfg.configBranch}" "nix-config" || true

          # Clone nix-secrets
          clone_repo "$SECRETS_DIR" "${repoCfg.secretsRepoSsh}" "${repoCfg.secretsRepoHttps}" "${repoCfg.secretsBranch}" "nix-secrets" || true

          echo "Repo setup complete"
        '';
      };
    })
  ];
}
