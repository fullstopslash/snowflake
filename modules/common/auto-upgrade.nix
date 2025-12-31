# Auto-Upgrade Module
#
# Provides automatic system updates with:
# - Remote flake upgrade (pulls from GitHub)
# - Local clone sync (jj-first VCS operations)
# - Configurable schedule and retention
# - Safety checks (only upgrade if newer)
# - Pre-update hooks (custom commands before pull)
# - Build validation (prevents broken deploys)
# - Datever-style commit messages (YYYY.MM.DD.HH.MM)
#
# Integration with chezmoi-sync (Phase 15-03a):
# - chezmoi-pre-update.service runs BEFORE auto-upgrade
# - Captures local dotfile changes before config pull
# - Ensures dotfiles and config stay synchronized
# - CRITICAL: Chezmoi commits FIRST, then main repo commits
#
# Modes:
#   remote: Uses system.autoUpgrade to pull from remote flake URL
#   local:  Jujutsu-first sync + rebuild (requires nixConfigRepo)
#
# VCS Strategy:
# - Prefers jujutsu (jj) for conflict-free auto-merging
# - Initializes jj co-located repos automatically
# - Handles parallel commits gracefully (no manual merge needed)
# - Falls back to git if jj is not available
#
# IMPORTANT: Local mode runs as primaryUsername (not root) because `nh os`
# refuses to run as root. The user must have passwordless sudo configured:
#   security.sudo.wheelNeedsPassword = false;
# This is already configured in the "test" role.
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
  home = config.identity.home;
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

        # Local mode: jj-first sync + nh rebuild
        systemd.services.nix-local-upgrade = lib.mkIf (cfg.mode == "local") {
          description = "Pull nix-config and rebuild system (jj-first)";
          after = [
            "network-online.target"
            "chezmoi-pre-update.service"
          ];
          wants = [ "network-online.target" ];
          startAt = cfg.schedule;
          path = with pkgs; [
            jujutsu
            git
            openssh
            nh
            nix
            sudo
            chezmoi
            coreutils
            gnugrep
            nettools
          ];
          environment.PATH = lib.mkForce "/run/wrappers/bin:${
            lib.makeBinPath (
              with pkgs;
              [
                jujutsu
                git
                openssh
                nh
                nix
                sudo
                chezmoi
                coreutils
                gnugrep
                systemd
                nettools
              ]
            )
          }";
          serviceConfig = {
            Type = "oneshot";
            User = config.identity.primaryUsername;
            Environment = "HOME=${home}";
            WorkingDirectory = home;
            # Accept environment variables for flag passing from `just rebuild`
            PassEnvironment = "SKIP_UPSTREAM SKIP_DOTFILES SKIP_UPDATE DRY_RUN OFFLINE";
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
                    echo "Rolling back VCS changes..."
                    if [ "$VCS_TYPE" = "jj" ]; then
                      jj -R "$CONFIG_DIR" edit "$old_commit" 2>/dev/null || true
                      [ -n "''${old_secrets_commit:-}" ] && jj -R "$SECRETS_DIR" edit "$old_secrets_commit" 2>/dev/null || true
                    else
                      git -C "$CONFIG_DIR" reset --hard "$old_commit"
                      [ -n "''${old_secrets_commit:-}" ] && git -C "$SECRETS_DIR" reset --hard "$old_secrets_commit" || true
                    fi
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
              CHEZMOI_DIR="${home}/.local/share/chezmoi"
              DATEVER=$(date +%Y.%m.%d.%H.%M)
              HOSTNAME=$(hostname)
              validation_failed=0

              # Parse flag environment variables (for `just rebuild` integration)
              # Supports: SKIP_UPSTREAM, SKIP_DOTFILES, SKIP_UPDATE, DRY_RUN, OFFLINE
              SKIP_UPSTREAM=''${SKIP_UPSTREAM:-false}
              SKIP_DOTFILES=''${SKIP_DOTFILES:-false}
              SKIP_UPDATE=''${SKIP_UPDATE:-true}
              DRY_RUN=''${DRY_RUN:-false}
              OFFLINE=''${OFFLINE:-false}

              # Offline mode sets both skip flags
              if [ "$OFFLINE" = "true" ]; then
                SKIP_UPSTREAM=true
                SKIP_DOTFILES=true
              fi

              # Dry-run helper
              maybe_run() {
                if [ "$DRY_RUN" = "true" ]; then
                  echo "[DRY-RUN] $*"
                else
                  "$@"
                fi
              }

              echo "=== Nix Local Upgrade: $(date) ==="
              echo "Using datever: $DATEVER"

              # Show active flags
              flags=""
              [ "$SKIP_UPSTREAM" = "true" ] && flags="$flags skip-upstream"
              [ "$SKIP_DOTFILES" = "true" ] && flags="$flags skip-dotfiles"
              [ "$SKIP_UPDATE" = "true" ] && flags="$flags skip-update"
              [ "$DRY_RUN" = "true" ] && flags="$flags dry-run"
              [ "$OFFLINE" = "true" ] && flags="$flags offline"
              [ -n "$flags" ] && echo "Flags:$flags"

              # Detect VCS type (prefer jj)
              if command -v jj &>/dev/null && [ -d "$CONFIG_DIR/.jj" ]; then
                VCS_TYPE="jj"
                echo "Using jujutsu for version control"
              elif command -v git &>/dev/null && [ -d "$CONFIG_DIR/.git" ]; then
                VCS_TYPE="git"
                echo "Using git for version control"
              else
                echo "Error: No VCS found in $CONFIG_DIR"
                exit 1
              fi

              # Helper: Get current commit ID
              get_commit() {
                local dir="$1"
                if [ "$VCS_TYPE" = "jj" ]; then
                  jj -R "$dir" log -r @ --no-graph -T 'commit_id' 2>/dev/null || echo ""
                else
                  git -C "$dir" rev-parse HEAD 2>/dev/null || echo ""
                fi
              }

              # Helper: Sync repo with upstream (jj-first with auto-merge)
              sync_repo() {
                local dir="$1"
                local name="$2"

                echo "Syncing $name..."
                cd "$dir"

                if [ "$VCS_TYPE" = "jj" ]; then
                  # Initialize jj if needed (co-located with git)
                  if [ ! -d .jj ]; then
                    echo "Initializing jj co-located repo in $name..."
                    jj git init --colocate || return 1
                  fi

                  # Fetch upstream
                  echo "Fetching upstream changes..."
                  if ! jj git fetch 2>&1; then
                    echo "Warning: Could not fetch $name (network issue?)"
                    return 1
                  fi

                  # Get trunk branch (dev, main, or master)
                  TRUNK_BRANCH="dev"
                  for branch in dev main master; do
                    if jj log -r "''${branch}@origin" --no-graph -T 'change_id' 2>/dev/null | grep -q .; then
                      TRUNK_BRANCH="$branch"
                      break
                    fi
                  done

                  # Try simple rebase first
                  if ! jj rebase -d "''${TRUNK_BRANCH}@origin" 2>&1; then
                    echo "Rebase had issues, attempting auto-merge..."

                    # Create merge commit (jj handles conflicts automatically)
                    if ! jj new "@-" "''${TRUNK_BRANCH}@origin" -m "merge: auto-merge with upstream $DATEVER" 2>&1; then
                      echo "Error: Could not create merge commit for $name"
                      return 1
                    fi

                    # Check for conflicts
                    if jj log -r @ --no-graph -T 'if(conflict, "CONFLICT")' 2>/dev/null | grep -q "CONFLICT"; then
                      echo "Error: $name has file conflicts that need manual resolution"
                      jj resolve --list 2>/dev/null | head -20
                      return 1
                    fi

                    echo "Auto-merge successful (no conflicts)"
                  else
                    echo "Rebased cleanly onto upstream"
                  fi
                else
                  # Fallback to git
                  if ! git fetch --all --prune 2>&1; then
                    echo "Warning: Could not fetch $name"
                    return 1
                  fi

                  if ! git pull --ff-only 2>&1; then
                    echo "Warning: git pull failed for $name (local changes?)"
                    return 1
                  fi
                fi

                return 0
              }

              # =================================================================
              # CRITICAL ORDER: Chezmoi FIRST, then main repo
              # This ensures dotfiles are committed before nix-config pulls,
              # preventing dotfile overwrites from chezmoi managed files
              # =================================================================

              # Sync chezmoi dotfiles (FIRST, before nix-config)
              if [ "$SKIP_DOTFILES" = "false" ]; then
                if [ -d "$CHEZMOI_DIR" ]; then
                  echo "Syncing chezmoi dotfiles..."
                  cd "$CHEZMOI_DIR"

                  # Initialize jj if needed
                  if [ "$VCS_TYPE" = "jj" ] && [ ! -d .jj ]; then
                    echo "Initializing jj co-located repo in chezmoi..."
                    maybe_run jj git init --colocate || true
                  fi

                  # Re-add dotfiles (capture current state)
                  if command -v chezmoi &>/dev/null; then
                    maybe_run chezmoi re-add
                  fi

                  # Commit if changes exist
                  if [ "$VCS_TYPE" = "jj" ]; then
                    if ! jj diff --quiet 2>/dev/null; then
                      echo "Committing chezmoi changes with datever..."
                      maybe_run jj describe -m "chore(dotfiles): automated sync $DATEVER"
                    fi

                    # Fetch and auto-merge
                    if ! maybe_run jj git fetch 2>&1; then
                      echo "Warning: Could not fetch chezmoi repo (network issue?)"
                    else
                      # Try rebase, fallback to merge
                      if ! maybe_run jj rebase -d 'latest(remote_bookmarks())' 2>&1; then
                        maybe_run jj new @ 'latest(remote_bookmarks())' -m "merge: auto-merge dotfiles $DATEVER" || true
                      fi
                    fi

                    # Push changes
                    maybe_run jj git push || echo "Warning: Could not push chezmoi changes"
                  fi
                else
                  echo "Chezmoi directory not found at $CHEZMOI_DIR, skipping"
                fi
              else
                echo "Skipping chezmoi sync (SKIP_DOTFILES=true)"
              fi

              # Save current commits for rollback
              old_commit=$(get_commit "$CONFIG_DIR")
              echo "Current nix-config commit: ''${old_commit:0:12}"

              old_secrets_commit=""
              if [ -d "$SECRETS_DIR" ]; then
                old_secrets_commit=$(get_commit "$SECRETS_DIR")
                echo "Current nix-secrets commit: ''${old_secrets_commit:0:12}"
              fi

              # Sync nix-config (AFTER chezmoi has already committed)
              if [ "$SKIP_UPSTREAM" = "false" ]; then
                if ! maybe_run sync_repo "$CONFIG_DIR" "nix-config"; then
                  echo "Error: Failed to sync nix-config"
                  [ "$DRY_RUN" = "false" ] && exit 1
                fi
              else
                echo "Skipping upstream sync (SKIP_UPSTREAM=true)"
              fi

              # Sync nix-secrets
              if [ "$SKIP_UPSTREAM" = "false" ] && [ -d "$SECRETS_DIR" ]; then
                if ! maybe_run sync_repo "$SECRETS_DIR" "nix-secrets"; then
                  echo "Warning: Failed to sync nix-secrets, continuing anyway"
                fi
              fi

              # Flake update (if requested via --update flag)
              if [ "$SKIP_UPDATE" = "false" ]; then
                echo "Updating flake inputs..."
                cd "$CONFIG_DIR"
                if ! maybe_run nix flake update; then
                  echo "Warning: Flake update failed, continuing with current lock"
                fi
              else
                echo "Skipping flake update (SKIP_UPDATE=true)"
              fi

              ${
                if cfg.buildBeforeSwitch then
                  ''
                    # Build first (don't switch yet)
                    echo "Building new configuration..."
                    if ! maybe_run nh os build "$CONFIG_DIR" --no-nom --out-link "$CONFIG_DIR/result"; then
                      echo "❌ Build failed, rolling back"
                      [ "$DRY_RUN" = "false" ] && ${rollbackAction}
                    fi

                    ${validationScript}

                    # Check if validation failed
                    if [ "$validation_failed" -eq 1 ]; then
                      [ "$DRY_RUN" = "false" ] && ${rollbackAction}
                    fi

                    # All checks passed, now switch
                    echo "✅ Build and validation passed, switching to new configuration..."
                    maybe_run nh os switch "$CONFIG_DIR" --no-nom --elevation-program sudo
                  ''
                else
                  ''
                    # Skip build-before-switch, go straight to switch
                    echo "Rebuilding system (buildBeforeSwitch=false)..."
                    maybe_run nh os switch "$CONFIG_DIR" --no-nom --elevation-program sudo
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
                User = config.identity.primaryUsername;
              };
            }
          ) cfg.preUpdateHooks
        );
      })
    ]
  );
}
