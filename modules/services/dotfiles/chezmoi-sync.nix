# Chezmoi Sync Module
#
# Automatically synchronizes chezmoi dotfiles repository using Jujutsu (jj)
# for conflict-free multi-host management.
#
# Features:
# - Conflict-free sync using jj (concurrent edits become parallel commits)
# - Automatic sync before OS updates (captures local changes)
# - Graceful network failure handling (offline-friendly)
# - Manual commands: chezmoi-sync, chezmoi-status, chezmoi-show-conflicts
# - State tracking for debugging
#
# Workflow:
#   jj git fetch → jj rebase → chezmoi re-add → jj describe → jj git push
#
# Why jj:
# - No manual conflict resolution needed
# - All changes preserved as separate commits
# - Simpler automation (no complex merge logic)
# - Offline-first design

{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.myModules.services.dotfiles.chezmoiSync;
  sopsFolder = builtins.toString inputs.nix-secrets + "/sops";

  # Get primary user (assumes single-user system for now)
  # TODO: Make this configurable or support multi-user
  primaryUser = config.users.users.rain or null;

  # Sync script using jj commands
  syncScript = pkgs.writeShellScript "chezmoi-sync" ''
    set -euo pipefail

    CHEZMOI_DIR="$HOME/.local/share/chezmoi"
    STATE_DIR="/var/lib/chezmoi-sync"
    STATE_FILE="$STATE_DIR/last-sync-status"
    HOSTNAME=$(${pkgs.nettools}/bin/hostname)

    mkdir -p "$STATE_DIR"

    log() {
      echo "[chezmoi-sync] $*"
      logger -t chezmoi-sync "$*"
    }

    # Check if chezmoi directory exists
    if [ ! -d "$CHEZMOI_DIR" ]; then
      log "Error: Chezmoi directory does not exist: $CHEZMOI_DIR"
      log "Run 'chezmoi init ${cfg.repoUrl}' first"
      echo "not-initialized" > "$STATE_FILE"
      exit 0  # Don't fail hard, just skip
    fi

    cd "$CHEZMOI_DIR"

    # Ensure jj is initialized (co-located with git)
    if [ ! -d .jj ]; then
      log "Initializing jj co-located repo..."
      ${pkgs.jujutsu}/bin/jj git init --colocate
    fi

    # Step 1: Fetch remote changes via jj
    log "Fetching remote changes..."
    if ! ${pkgs.jujutsu}/bin/jj git fetch 2>&1; then
      log "Warning: Could not fetch (no network?)"
      echo "fetch-failed" > "$STATE_FILE"
      exit 0  # Don't fail, just skip sync
    fi

    # Step 2: Rebase working copy on latest remote
    log "Rebasing working copy on remote changes..."
    # jj automatically handles conflicts by creating separate commits
    if ! ${pkgs.jujutsu}/bin/jj rebase -d @- -s @ 2>&1; then
      log "Warning: Rebase had issues, but continuing..."
    fi

    # Check if conflicts exist (for logging)
    if ${pkgs.jujutsu}/bin/jj log --conflicts -r @ --no-graph 2>/dev/null | grep -q .; then
      log "Note: Conflicts detected - preserved as separate commits"
      echo "conflicts-preserved" > "$STATE_FILE"
    fi

    # Step 3: Capture current dotfiles state
    ${lib.optionalString cfg.autoCommit ''
      log "Capturing current dotfiles with chezmoi re-add..."
      ${pkgs.chezmoi}/bin/chezmoi re-add
    ''}

    # Step 4: Check if there are actual changes to commit
    ${lib.optionalString cfg.autoCommit ''
      if ${pkgs.jujutsu}/bin/jj diff --quiet 2>/dev/null; then
        log "No dotfile changes to commit"
      else
        # Update working copy description with datever format (YYYY-MM-DD-HHMM)
        DATEVER=$(${pkgs.coreutils}/bin/date +%Y-%m-%d-%H%M)
        log "Updating commit description with datever: $DATEVER"
        ${pkgs.jujutsu}/bin/jj describe -m "chore(dotfiles): auto-update $DATEVER on $HOSTNAME"
      fi
    ''}

    # Step 5: Push to git remote
    ${lib.optionalString cfg.autoPush ''
      log "Pushing to git remote..."
      if ${pkgs.jujutsu}/bin/jj git push 2>&1; then
        log "Successfully pushed changes"
        echo "success" > "$STATE_FILE"
      else
        log "Warning: Could not push (no network?)"
        echo "push-failed" > "$STATE_FILE"
        # Don't fail - changes are committed locally
        # jj will push on next successful sync
        exit 0
      fi
    ''}

    ${lib.optionalString (!cfg.autoPush) ''
      echo "success-local-only" > "$STATE_FILE"
    ''}

    log "Chezmoi sync complete"
  '';

  # Manual status command
  statusCmd = pkgs.writeShellScriptBin "chezmoi-status" ''
    CHEZMOI_DIR="$HOME/.local/share/chezmoi"
    STATE_FILE="/var/lib/chezmoi-sync/last-sync-status"

    echo "=== Chezmoi Sync Status ==="
    echo ""

    # Show last sync status
    if [ -f "$STATE_FILE" ]; then
      STATUS=$(cat "$STATE_FILE")
      echo "Last sync: $STATUS"
    else
      echo "Last sync: Never"
    fi

    echo ""

    # Show jj status
    if [ -d "$CHEZMOI_DIR/.jj" ]; then
      cd "$CHEZMOI_DIR"
      echo "=== jj Working Copy Status ==="
      ${pkgs.jujutsu}/bin/jj status
      echo ""
      echo "=== Recent jj Log ==="
      ${pkgs.jujutsu}/bin/jj log --limit 5
    else
      echo "jj not initialized in chezmoi directory"
      echo "Run: cd $CHEZMOI_DIR && jj git init --colocate"
    fi
  '';

  # Manual conflict checker
  showConflictsCmd = pkgs.writeShellScriptBin "chezmoi-show-conflicts" ''
    CHEZMOI_DIR="$HOME/.local/share/chezmoi"

    if [ ! -d "$CHEZMOI_DIR/.jj" ]; then
      echo "Error: jj not initialized in chezmoi directory"
      exit 1
    fi

    cd "$CHEZMOI_DIR"

    echo "=== Checking for conflicts in jj log ==="
    if ${pkgs.jujutsu}/bin/jj log --conflicts --limit 20 | grep -q .; then
      echo ""
      echo "Conflicts found. To resolve:"
      echo "  1. cd ~/.local/share/chezmoi"
      echo "  2. jj resolve (interactive resolution)"
      echo "  3. jj describe -m \"fix: reconcile conflicts\""
      echo "  4. jj git push"
    else
      echo "No conflicts found!"
    fi
  '';

  # Manual sync command (wrapper around systemd service)
  syncCmd = pkgs.writeShellScriptBin "chezmoi-sync" ''
    echo "Running chezmoi sync..."
    sudo systemctl start chezmoi-sync-manual.service

    echo ""
    echo "Sync complete. Check status with: chezmoi-status"
    echo "Or view logs with: journalctl -u chezmoi-sync-manual.service"
  '';
in
{
  options.myModules.services.dotfiles.chezmoiSync = {
    enable = lib.mkEnableOption "automatic chezmoi repository synchronization";
    repoUrl = lib.mkOption {
      type = lib.types.str;
      example = "git@github.com:user/dotfiles.git";
      description = ''
        Git URL for chezmoi dotfiles repository.
        jj uses git as a backend for remote operations.
      '';
    };

    syncBeforeUpdate = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Automatically sync chezmoi before OS updates.
        Creates chezmoi-pre-update.service that runs before auto-upgrade.
      '';
    };

    autoCommit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Automatically commit local changes with hostname and timestamp.
        Commits use format: "chore(hostname): sync dotfiles - timestamp"
      '';
    };

    autoPush = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Automatically push commits to remote.
        Fails gracefully if no network - changes remain local until next sync.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Validate that primary user exists
    assertions = [
      {
        assertion = primaryUser != null;
        message = "chezmoi-sync requires user 'rain' to exist";
      }
    ];

    # Install required packages
    environment.systemPackages = [
      pkgs.jujutsu # Required for conflict-free sync
      pkgs.chezmoi # Dotfile manager
      statusCmd
      showConflictsCmd
      syncCmd
    ];

    # Pre-update service (runs before auto-upgrade if enabled)
    systemd.services.chezmoi-pre-update = lib.mkIf cfg.syncBeforeUpdate {
      description = "Sync chezmoi dotfiles before OS update";
      documentation = [ "Captures local dotfile changes and syncs with remote" ];

      # Run before auto-upgrade (if it exists)
      before = lib.optional (config.myModules.services.autoUpgrade.enable or false
      ) "nix-local-upgrade.service";

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${syncScript}";
        # Run as the primary user (not root)
        User = primaryUser.name;
        Environment = "HOME=${primaryUser.home}";
      };
    };

    # Manual sync service (for testing/debugging)
    systemd.services.chezmoi-sync-manual = {
      description = "Manual chezmoi sync (for testing)";

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${syncScript}";
        User = primaryUser.name;
        Environment = "HOME=${primaryUser.home}";
      };
    };

    # State directory
    systemd.tmpfiles.rules = [
      "d /var/lib/chezmoi-sync 0755 root root -"
    ];

    # SOPS secrets for dotfiles (if hasSecrets is enabled)
    sops.secrets =
      lib.mkIf ((config.sops.defaultSopsFile or null) != null) {
        acoustid_api = {
          sopsFile = "${sopsFolder}/shared.yaml";
          key = "dotfiles/acoustid_api"; # Read from dotfiles.acoustid_api in SOPS
          owner = primaryUser.name;
          mode = "0400";
          # Deploys to /run/secrets/acoustid_api
        };

        "rain-age-key" = {
          sopsFile = "${sopsFolder}/shared.yaml";
          key = "user-keys/rain-age-key";
          path = "${primaryUser.home}/.config/sops/age/keys.txt";
          owner = primaryUser.name;
          mode = "0400";
          # Deploys user age key for decrypting user-specific secrets
        };
      };
  };
}
