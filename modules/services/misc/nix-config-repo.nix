# Auto-clone nix-config and nix-secrets repos for distributed management
#
# This module ensures each host has local clones of the config repos at:
# - ~/nix-config - main NixOS configuration flake
# - ~/nix-secrets - encrypted secrets repo
# - /etc/nixos -> ~/nix-config (symlink for system compatibility)
#
# This enables:
# - Running `nh os switch` from any host
# - Running `nixos-rebuild switch --flake /etc/nixos` (standard NixOS path)
# - Pulling updates from GitHub instead of pushing via SSH
# - Distributed config management across multiple machines
#
# Clone strategy:
# 1. Try SSH URL first (allows push access if key is configured)
# 2. Fall back to HTTPS URL (read-only, but works without auth)
# 3. User can later switch remote to SSH for push access

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.services.nixConfigRepo;
  user = config.hostSpec.primaryUsername;
  home = config.hostSpec.home;
in
{
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

  config = lib.mkIf cfg.enable {
    # Create /etc/nixos symlink pointing to user's nix-config
    # This allows standard `nixos-rebuild --flake /etc/nixos` to work
    environment.etc."nixos".source = lib.mkForce "${home}/nix-config";

    # Systemd user service to clone repos on first login
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
        clone_repo "$CONFIG_DIR" "${cfg.configRepoSsh}" "${cfg.configRepoHttps}" "${cfg.configBranch}" "nix-config" || true

        # Clone nix-secrets
        clone_repo "$SECRETS_DIR" "${cfg.secretsRepoSsh}" "${cfg.secretsRepoHttps}" "${cfg.secretsBranch}" "nix-secrets" || true

        echo "Repo setup complete"
      '';
    };
  };
}
