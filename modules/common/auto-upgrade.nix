# Auto-Upgrade Module
#
# Provides automatic system updates with:
# - Remote flake upgrade (pulls from GitHub)
# - Local clone sync (git pull + rebuild)
# - Configurable schedule and retention
# - Safety checks (only upgrade if newer)
# - Pre-update hooks (custom commands before pull)
# - Build validation (prevents broken deploys)
#
# Integration with chezmoi-sync (Phase 15-03a):
# - chezmoi-pre-update.service runs before auto-upgrade
# - Captures local dotfile changes before config pull
# - Ensures dotfiles and config stay synchronized
#
# Modes:
#   remote: Uses system.autoUpgrade to pull from remote flake URL
#   local:  Git pulls local clone then rebuilds (requires nixConfigRepo)
#
# IMPORTANT: Local mode runs as primaryUsername (not root) because `nh os`
# refuses to run as root. The user must have passwordless sudo configured:
#   security.sudo.wheelNeedsPassword = false;
# This is already configured in the "test" role.
#
# Test: Auto-upgrade service verification - 2025-12-16
# Test 2: Verify auto-upgrade works after out-link fix
#
{
  config,
  lib,
  pkgs,
  ...
}:
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
      type = lib.types.enum [
        "remote"
        "local"
      ];
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
      type = lib.types.nullOr (
        lib.types.submodule {
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
        }
      );
      default = null;
      description = "If set, allow automatic reboots within this time window when kernel changes";
    };

    allowReboot = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow automatic reboots after upgrades (requires rebootWindow)";
    };

    buildBeforeSwitch = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Build and validate before switching (local mode only)";
    };

    validationChecks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Shell commands to run for validation (must exit 0)";
      example = [
        "systemctl --quiet is-enabled sshd"
        "test -f /etc/nixos/configuration.nix"
      ];
    };

    onValidationFailure = lib.mkOption {
      type = lib.types.enum [
        "rollback"
        "notify"
        "ignore"
      ];
      default = "rollback";
      description = "Action on validation failure (rollback git, notify only, or ignore)";
    };

    preUpdateHooks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Commands to run before pulling updates.
        Each command runs in its own systemd service.
        Useful for pre-update cleanup, backups, etc.
      '';
      example = [
        "''${pkgs.bash}/bin/bash /root/backup-state.sh"
        "''${pkgs.systemd}/bin/systemctl stop expensive-service"
      ];
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        # Validate mode=local requires nixConfigRepo
        assertions = [
          {
            assertion = cfg.mode == "remote" || repoCfg.enable;
            message = "autoUpgrade.mode = 'local' requires nixConfigRepo.enable = true";
          }
          {
            assertion = cfg.mode == "local" || cfg.preUpdateHooks == [ ];
            message = "preUpdateHooks only supported in local mode";
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
          path = with pkgs; [
            git
            openssh
            nh
            nix
          ];
          serviceConfig = {
            Type = "oneshot";
            User = config.hostSpec.primaryUsername;
            Environment = "HOME=${home}";
            WorkingDirectory = home;
          };
          script =
            let
              validationScript =
                if cfg.validationChecks != [ ] then
                  lib.concatMapStringsSep "\n" (check: ''
                    echo "Running validation: ${check}"
                    if ! ${check}; then
                      echo "❌ Validation failed: ${check}"
                      validation_failed=1
                    fi
                  '') cfg.validationChecks
                else
                  "";

              rollbackAction = ''
                case "${cfg.onValidationFailure}" in
                  rollback)
                    echo "Rolling back git changes..."
                    git -C "$CONFIG_DIR" reset --hard "$old_commit"
                    [ -n "''${old_secrets_commit:-}" ] && git -C "$SECRETS_DIR" reset --hard "$old_secrets_commit" || true
                    exit 1
                    ;;
                  notify)
                    echo "⚠️  Validation failed but continuing (onValidationFailure=notify)"
                    ;;
                  ignore)
                    echo "Ignoring validation failures"
                    ;;
                esac
              '';

            in
            ''
              set -eu
              CONFIG_DIR="${home}/nix-config"
              SECRETS_DIR="${home}/nix-secrets"
              validation_failed=0

              echo "=== Nix Local Upgrade: $(date) ==="

              # Save current commits for rollback
              old_commit=""
              old_secrets_commit=""
              if [ -d "$CONFIG_DIR/.git" ]; then
                old_commit=$(git -C "$CONFIG_DIR" rev-parse HEAD)
                echo "Current nix-config commit: $old_commit"
              fi

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
                old_secrets_commit=$(git -C "$SECRETS_DIR" rev-parse HEAD)
                echo "Current nix-secrets commit: $old_secrets_commit"
                echo "Pulling nix-secrets..."
                git -C "$SECRETS_DIR" fetch --all --prune
                git -C "$SECRETS_DIR" pull --ff-only || {
                  echo "Warning: git pull failed for secrets, continuing anyway"
                }
              fi

              ${
                if cfg.buildBeforeSwitch then
                  ''
                    # Build first (don't switch yet)
                    echo "Building new configuration..."
                    if ! nh os build "$CONFIG_DIR" --no-nom --out-link "$CONFIG_DIR/result"; then
                      echo "❌ Build failed, rolling back"
                      git -C "$CONFIG_DIR" reset --hard "$old_commit"
                      [ -n "''${old_secrets_commit:-}" ] && git -C "$SECRETS_DIR" reset --hard "$old_secrets_commit" || true
                      exit 1
                    fi

                    ${validationScript}

                    # Check if validation failed
                    if [ "$validation_failed" -eq 1 ]; then
                      ${rollbackAction}
                    fi

                    # All checks passed, now switch
                    echo "✅ Build and validation passed, switching to new configuration..."
                    nh os switch "$CONFIG_DIR" --no-nom
                  ''
                else
                  ''
                    # Skip build-before-switch, go straight to switch
                    echo "Rebuilding system (buildBeforeSwitch=false)..."
                    nh os switch "$CONFIG_DIR" --no-nom
                  ''
              }

              echo "=== Upgrade complete: $(date) ==="
            '';
        };

        # Configure nh cleanup with our retention settings
        # Use mkDefault so nix-management.nix settings take precedence
        programs.nh.clean = {
          enable = true;
          extraArgs = lib.mkDefault "--keep-since ${toString cfg.keepDays}d --keep ${toString cfg.keepGenerations}";
        };
      }

      # Pre-update hook services (one service per hook)
      # Creates dynamic service definitions from preUpdateHooks list
      (lib.mkIf (cfg.mode == "local") {
        systemd.services = lib.listToAttrs (
          lib.imap0 (
            idx: hookCmd:
            lib.nameValuePair "auto-upgrade-pre-hook-${toString idx}" {
              description = "Auto-upgrade pre-update hook ${toString idx}";
              before = [ "nix-local-upgrade.service" ];
              wantedBy = [ "nix-local-upgrade.service" ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = hookCmd;
                User = config.hostSpec.primaryUsername;
              };
            }
          ) cfg.preUpdateHooks
        );
      })
    ]
  );
}
