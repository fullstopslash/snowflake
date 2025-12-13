# Auto-Upgrade Module
#
# Provides automatic system updates with:
# - Remote flake upgrade (pulls from GitHub)
# - Local clone sync (git pull + rebuild)
# - Configurable schedule and retention
# - Safety checks (only upgrade if newer)
#
# Modes:
#   remote: Uses system.autoUpgrade to pull from remote flake URL
#   local:  Git pulls local clone then rebuilds (requires nixConfigRepo)
#
{ config, lib, pkgs, ... }:
let
  cfg = config.myModules.services.autoUpgrade;
  repoCfg = config.myModules.services.nixConfigRepo;
  home = config.hostSpec.home;
  isClean = config.system ? configurationRevision;
in
{
  options.myModules.services.autoUpgrade = {
    enable = lib.mkEnableOption "Automatic system upgrades";

    mode = lib.mkOption {
      type = lib.types.enum [ "remote" "local" ];
      default = "remote";
      description = ''
        Upgrade mode:
        - remote: Pull directly from remote flake URL (default)
        - local: Git pull local clone then rebuild (requires nixConfigRepo.enable)
      '';
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "04:00";
      example = "hourly";
      description = "When to run auto-upgrade (systemd calendar format)";
    };

    flakeUrl = lib.mkOption {
      type = lib.types.str;
      default = "github:fullstopslash/snowflake?ref=dev";
      description = "Remote flake URL for upgrades";
    };

    keepGenerations = lib.mkOption {
      type = lib.types.int;
      default = 10;
      description = "Number of NixOS generations to keep";
    };

    keepDays = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Keep generations newer than this many days";
    };

    rebootWindow = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          lower = lib.mkOption {
            type = lib.types.str;
            example = "01:00";
            description = "Start of reboot window";
          };
          upper = lib.mkOption {
            type = lib.types.str;
            example = "05:00";
            description = "End of reboot window";
          };
        };
      });
      default = null;
      description = "If set, allow automatic reboots within this time window when kernel changes";
    };

    allowReboot = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow automatic reboots after upgrades (requires rebootWindow)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Validate mode=local requires nixConfigRepo
    assertions = [
      {
        assertion = cfg.mode == "remote" || repoCfg.enable;
        message = "autoUpgrade.mode = 'local' requires nixConfigRepo.enable = true";
      }
    ];

    # Remote mode: use built-in system.autoUpgrade
    system.autoUpgrade = lib.mkIf (cfg.mode == "remote") {
      enable = isClean;
      dates = cfg.schedule;
      flags = [ "--refresh" ];
      flake = cfg.flakeUrl;
      allowReboot = cfg.allowReboot;
      rebootWindow = cfg.rebootWindow;
    };

    # Only run if current config is older than remote
    systemd.services.nixos-upgrade = lib.mkIf (cfg.mode == "remote" && isClean) {
      serviceConfig.ExecCondition = lib.getExe (
        pkgs.writeShellScriptBin "check-newer" ''
          lastModified() {
            nix flake metadata "$1" --refresh --json | ${lib.getExe pkgs.jq} '.lastModified'
          }
          remote_time=$(lastModified "${cfg.flakeUrl}")
          local_time=$(lastModified "self")
          if [ "$remote_time" -gt "$local_time" ]; then
            echo "Remote ($remote_time) is newer than local ($local_time), proceeding"
            exit 0
          else
            echo "Local ($local_time) is up to date with remote ($remote_time), skipping"
            exit 1
          fi
        ''
      );
    };

    # Local mode: git pull + nh rebuild
    systemd.services.nix-local-upgrade = lib.mkIf (cfg.mode == "local") {
      description = "Pull nix-config and rebuild system";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      startAt = cfg.schedule;
      path = with pkgs; [ git openssh nh nix ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Environment = "HOME=/root";
      };
      script = ''
        set -eu
        CONFIG_DIR="${home}/nix-config"
        SECRETS_DIR="${home}/nix-secrets"

        echo "=== Nix Local Upgrade: $(date) ==="

        # Pull nix-config
        if [ -d "$CONFIG_DIR/.git" ]; then
          echo "Pulling nix-config..."
          git -C "$CONFIG_DIR" fetch --all --prune
          git -C "$CONFIG_DIR" pull --ff-only || {
            echo "Warning: git pull failed (local changes?), continuing anyway"
          }
        else
          echo "Warning: $CONFIG_DIR is not a git repo"
        fi

        # Pull nix-secrets
        if [ -d "$SECRETS_DIR/.git" ]; then
          echo "Pulling nix-secrets..."
          git -C "$SECRETS_DIR" fetch --all --prune
          git -C "$SECRETS_DIR" pull --ff-only || {
            echo "Warning: git pull failed for secrets, continuing anyway"
          }
        fi

        # Rebuild with nh
        echo "Rebuilding system..."
        nh os switch "$CONFIG_DIR" --no-nom

        echo "=== Upgrade complete: $(date) ==="
      '';
    };

    # Configure nh cleanup with our retention settings
    programs.nh.clean = {
      enable = true;
      extraArgs = "--keep-since ${toString cfg.keepDays}d --keep ${toString cfg.keepGenerations}";
    };
  };
}
