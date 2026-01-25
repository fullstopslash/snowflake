# Vikunja sync role - bidirectional multi-project sync between Taskwarrior and Vikunja
#
# Architecture:
# - Real-time: TW on-modify hook -> vikunja-direct push -> Vikunja API (instant)
# - Real-time: Vikunja webhook -> vikunja-direct webhook -> TW import (instant)
# - Reconciliation: Periodic full sync via syncall (hourly fallback)
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.roles.vikunjaSync;
  secrets = inputs.nix-secrets;
  username = config.hostSpec.primaryUser;
  homeDir = config.users.users.${username}.home;

  vikunjaSync = pkgs.callPackage ../pkgs/vikunja-sync/default.nix {};

  # User-specific state directory for queue, logs, and locks
  stateDir = "${homeDir}/.local/state/vikunja-sync";

  # Script to process failed sync queue (POSIX-compliant with flock locking)
  processQueueScript = pkgs.writeShellScript "vikunja-process-queue" ''
    STATE_DIR="${stateDir}"
    QUEUE_FILE="$STATE_DIR/queue.txt"
    LOG_FILE="$STATE_DIR/direct.log"
    LOCK_FILE="$STATE_DIR/queue.lock"

    # Ensure state directory exists
    mkdir -p "$STATE_DIR"

    # Exit if no queue file
    [ ! -f "$QUEUE_FILE" ] && exit 0

    # Acquire exclusive lock (skip if another process has it)
    exec 9>"$LOCK_FILE"
    ${pkgs.util-linux}/bin/flock -n 9 || exit 0

    export VIKUNJA_URL="${cfg.vikunjaUrl}"
    export VIKUNJA_USER="${cfg.caldavUser}"
    export VIKUNJA_API_TOKEN_FILE="${config.sops.secrets."caldav/vikunja-api".path}"
    export VIKUNJA_SYNC_RUNNING=1

    # Process unique UUIDs from queue
    sort -u "$QUEUE_FILE" | while read -r uuid; do
      [ -z "$uuid" ] && continue
      echo "[$(date -Iseconds)] Retrying sync for $uuid" >> "$LOG_FILE"
      if ${vikunjaSync}/bin/vikunja-direct push "$uuid" 2>> "$LOG_FILE"; then
        sed -i "/^$uuid$/d" "$QUEUE_FILE"
      fi
    done

    # Clean up empty queue file
    [ ! -s "$QUEUE_FILE" ] && rm -f "$QUEUE_FILE"
  '';

  # Script to sync a specific project (used by reconciliation)
  syncProjectScript = pkgs.writeShellScript "vikunja-sync-project" ''
    PROJECT="$1"
    if [ -z "$PROJECT" ]; then
      echo "Usage: $0 <project-name>"
      exit 1
    fi

    export VIKUNJA_URL="${cfg.vikunjaUrl}"
    export VIKUNJA_USER="${cfg.caldavUser}"
    export VIKUNJA_API_TOKEN_FILE="${config.sops.secrets."caldav/vikunja-api".path}"
    export VIKUNJA_CALDAV_PASS_FILE="${config.sops.secrets."caldav/vikunja".path}"

    exec ${vikunjaSync}/bin/vikunja-sync project "$PROJECT"
  '';

  # Script to sync all projects (reconciliation)
  syncAllScript = pkgs.writeShellScript "vikunja-sync-all" ''
    export VIKUNJA_URL="${cfg.vikunjaUrl}"
    export VIKUNJA_USER="${cfg.caldavUser}"
    export VIKUNJA_API_TOKEN_FILE="${config.sops.secrets."caldav/vikunja-api".path}"
    export VIKUNJA_CALDAV_PASS_FILE="${config.sops.secrets."caldav/vikunja".path}"

    exec ${vikunjaSync}/bin/vikunja-sync all
  '';
in {
  options.roles.vikunjaSync = {
    enable = lib.mkEnableOption "Vikunja bidirectional multi-project sync";

    vikunjaUrl = lib.mkOption {
      type = lib.types.str;
      default = secrets.services.vikunja.url;
      description = "Vikunja instance URL";
    };

    caldavUser = lib.mkOption {
      type = lib.types.str;
      default = secrets.services.vikunja.user;
      description = "CalDAV/Vikunja username";
    };

    enableReconciliation = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable periodic full sync (usually not needed with direct sync + webhooks)";
    };

    reconcileInterval = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "Full reconciliation sync interval in minutes (if enabled)";
    };

    enableDirectSync = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable direct TW<->Vikunja sync via hooks (instant, no full scan)";
    };

    enableTaskChampionSync = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable async TaskChampion sync after any task change";
    };

    defaultProject = lib.mkOption {
      type = lib.types.str;
      default = "inbox";
      description = "Default Vikunja project for TW tasks without a project";
    };
  };

  config = lib.mkIf cfg.enable {
    # Add sync tools to system packages
    environment.systemPackages = [
      vikunjaSync
      pkgs.taskwarrior3
    ];

    # NOTE: Webhooks are set on the root "Tasks" project (ID: 7) which catches
    # all child project events via webhook inheritance. No per-project webhook
    # setup needed. To revert to flat structure: ~/.local/bin/vikunja-flatten-projects

    # SOPS secrets
    sops.secrets = {
      "caldav/vikunja" = {
        key = "caldav/vikunja";
        owner = username;
        mode = "0600";
      };
      "caldav/vikunja-api" = {
        key = "caldav/vikunja-api";
        owner = username;
        mode = "0600";
      };
    };

    # Ensure directories exist
    systemd.tmpfiles.rules = [
      "d ${homeDir}/.config/task/hooks 0750 ${username} users -"
      "d ${stateDir} 0750 ${username} users -"
    ];

    # NetworkManager dispatcher - process queue and reconcile on network-up
    networking.networkmanager.dispatcherScripts = lib.mkIf cfg.enableDirectSync [
      {
        source = pkgs.writeShellScript "vikunja-network-up" ''
          [ "$2" != "up" ] && exit 0

          # Wait for network to stabilize
          sleep 2

          STATE_DIR="${stateDir}"
          LOG_FILE="$STATE_DIR/direct.log"

          # Process any queued failed syncs (as user)
          ${pkgs.sudo}/bin/sudo -u ${username} ${processQueueScript} &

          # Check if we need reconciliation (offline > 30 min)
          LAST_SYNC="$STATE_DIR/last-sync"
          NOW=$(date +%s)
          if [ -f "$LAST_SYNC" ]; then
            LAST=$(cat "$LAST_SYNC")
            OFFLINE_SEC=$((NOW - LAST))
            if [ $OFFLINE_SEC -gt 1800 ]; then
              echo "[$(date -Iseconds)] Offline for $((OFFLINE_SEC/60))min, triggering reconciliation" >> "$LOG_FILE"
              ${pkgs.sudo}/bin/sudo -u ${username} ${pkgs.systemd}/bin/systemctl --user start vikunja-reconcile.service --no-block
            fi
          fi
          echo "$NOW" > "$LAST_SYNC"
        '';
        type = "basic";
      }
    ];

    # Reconciliation timer (periodic full sync as fallback)
    # With direct sync + webhooks, this is usually not needed
    systemd.user.timers.vikunja-sync = lib.mkIf cfg.enableReconciliation {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "10min";
        OnUnitActiveSec = "${toString cfg.reconcileInterval}min";
        Persistent = true;
      };
    };

    # Full sync service (only if reconciliation enabled via timer)
    systemd.user.services.vikunja-sync = lib.mkIf cfg.enableReconciliation {
      description = "Vikunja full bidirectional sync";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      path = [pkgs.taskwarrior3 pkgs.curl pkgs.jaq pkgs.yq-go pkgs.sops pkgs.bash pkgs.coreutils];
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = 300; # 5 min for full sync
        ExecStart = syncAllScript;
      };
    };

    # On-demand reconciliation service (triggered by network-up after offline period)
    # Always available, independent of enableReconciliation timer setting
    systemd.user.services.vikunja-reconcile = lib.mkIf cfg.enableDirectSync {
      description = "Vikunja on-demand reconciliation (network recovery)";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      path = [pkgs.taskwarrior3 pkgs.curl pkgs.jaq pkgs.yq-go pkgs.sops pkgs.bash pkgs.coreutils];
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = 300; # 5 min for full sync
        # Debounce: don't run if already ran recently
        ExecCondition = "${pkgs.bash}/bin/bash -c 'test ! -f ${stateDir}/reconcile.lock || test $(($(date +%%s) - $(stat -c %%Y ${stateDir}/reconcile.lock))) -gt 300'";
      };
      script = ''
        STATE_DIR="${stateDir}"
        LOG_FILE="$STATE_DIR/direct.log"
        mkdir -p "$STATE_DIR"

        touch "$STATE_DIR/reconcile.lock"
        echo "[$(date -Iseconds)] Starting reconciliation" >> "$LOG_FILE"

        # First, process the queue
        ${processQueueScript}

        # Then run full sync
        ${syncAllScript}

        echo "[$(date -Iseconds)] Reconciliation complete" >> "$LOG_FILE"
      '';
    };

    # Per-project sync service (triggered by webhook or hook)
    systemd.user.services.vikunja-sync-project = {
      description = "Vikunja per-project sync";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      path = [pkgs.taskwarrior3 pkgs.curl pkgs.jaq pkgs.yq-go pkgs.sops pkgs.bash pkgs.coreutils];
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = 120; # 2 min for single project
      };
      # Project name passed via VIKUNJA_SYNC_PROJECT env var
      script = ''
        if [ -z "''${VIKUNJA_SYNC_PROJECT:-}" ]; then
          echo "VIKUNJA_SYNC_PROJECT not set, running full sync"
          exec ${syncAllScript}
        fi
        exec ${syncProjectScript} "$VIKUNJA_SYNC_PROJECT"
      '';
    };

    # Retry queue processor service (processes failed syncs)
    systemd.user.services.vikunja-sync-retry = lib.mkIf cfg.enableDirectSync {
      description = "Vikunja Sync Retry Queue Processor";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      path = [vikunjaSync pkgs.taskwarrior3 pkgs.curl pkgs.jaq pkgs.bash pkgs.coreutils];
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = 120; # 2 min for retry processing
      };
      environment = {
        VIKUNJA_URL = cfg.vikunjaUrl;
        VIKUNJA_USER = cfg.caldavUser;
        VIKUNJA_API_TOKEN_FILE = config.sops.secrets."caldav/vikunja-api".path;
      };
      script = ''
        exec ${vikunjaSync}/bin/vikunja-sync-retry
      '';
    };

    # Retry queue timer (runs every 5 minutes)
    systemd.user.timers.vikunja-sync-retry = lib.mkIf cfg.enableDirectSync {
      description = "Run Vikunja Sync Retry every 5 minutes";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "5min";
      };
    };

    # Taskwarrior on-add hook - direct push to Vikunja API (instant sync for new tasks)
    # NON-BLOCKING: outputs task immediately, syncs in background
    environment.etc."vikunja-sync-hook/on-add-vikunja" = lib.mkIf cfg.enableDirectSync {
      mode = "0755";
      text = ''
        #!/bin/sh
        # Taskwarrior on-add hook - non-blocking push to Vikunja
        # Outputs task immediately, syncs in background for <10ms latency

        # Ensure system binaries are in PATH
        PATH="/run/current-system/sw/bin:$PATH"
        export PATH

        # Resolve binary paths at runtime (survives rebuilds)
        VIKUNJA_DIRECT=$(command -v vikunja-direct) || true
        JAQ=$(command -v jaq) || true
        TASK=$(command -v task) || true

        # Read the new task JSON
        read -r task_json

        # If required binaries missing, output task unchanged and exit (fail-open)
        if [ -z "$VIKUNJA_DIRECT" ] || [ -z "$JAQ" ]; then
          echo "$task_json"
          exit 0
        fi

        # If task has no project, add the default project before outputting
        # This ensures TW and Vikunja both have the same project
        if [ "$(echo "$task_json" | "$JAQ" -r '.project // empty')" = "" ]; then
          task_json=$(echo "$task_json" | "$JAQ" -c --arg proj "${cfg.defaultProject}" '.project = $proj')
        fi

        # Output (potentially modified) task so TW stores it with the project
        echo "$task_json"

        # Skip sync if we're already in a sync (prevents loops)
        [ -n "''${VIKUNJA_SYNC_RUNNING:-}" ] && exit 0

        # Background the sync via setsid (fully detached from terminal/TW)
        # Uses timeout to prevent hung processes
        STATE_DIR="${stateDir}"
        setsid sh -c '
          export VIKUNJA_URL="${cfg.vikunjaUrl}"
          export VIKUNJA_USER="${cfg.caldavUser}"
          export VIKUNJA_API_TOKEN_FILE="${config.sops.secrets."caldav/vikunja-api".path}"
          export VIKUNJA_DEFAULT_PROJECT="${cfg.defaultProject}"

          mkdir -p "$5"
          timeout 30 sh -c "echo \"\$1\" | \"\$2\" hook" _ "$1" "$2" >> "$5/direct.log" 2>&1
          exit_code=$?

          # On failure, queue for retry
          if [ $exit_code -ne 0 ]; then
            uuid=$(echo "$1" | "$3" -r ".uuid // empty")
            [ -n "$uuid" ] && echo "$uuid" >> "$5/queue.txt"
          fi
          ${lib.optionalString cfg.enableTaskChampionSync ''
          # TaskChampion sync (async, non-blocking)
          timeout 30 "$4" sync >> "$5/taskchampion-sync.log" 2>&1 || true
          ''}
        ' _ "$task_json" "$VIKUNJA_DIRECT" "$JAQ" "$TASK" "$STATE_DIR" </dev/null >/dev/null 2>&1 &

        exit 0
      '';
    };

    # Taskwarrior on-modify hook - direct push to Vikunja API (instant sync)
    # NON-BLOCKING: outputs task immediately, syncs in background
    # NOTE: TaskWarrior has no on-delete hook - deletion triggers on-modify with status:deleted
    environment.etc."vikunja-sync-hook/on-modify-vikunja" = lib.mkIf cfg.enableDirectSync {
      mode = "0755";
      text = ''
        #!/bin/sh
        # Taskwarrior on-modify hook - non-blocking push to Vikunja
        # Outputs modified task immediately, syncs in background for <10ms latency
        # NOTE: TaskWarrior deletion triggers on-modify with status:deleted (no on-delete hook)

        # Ensure system binaries are in PATH
        PATH="/run/current-system/sw/bin:$PATH"
        export PATH

        # Resolve binary paths at runtime (survives rebuilds)
        VIKUNJA_DIRECT=$(command -v vikunja-direct) || true
        JAQ=$(command -v jaq) || true
        TASK=$(command -v task) || true

        # Read original and modified task JSON
        read -r original_json
        read -r modified_json

        # Output modified task immediately so TW can continue (CRITICAL)
        echo "$modified_json"

        # If required binaries missing, exit (fail-open - task already output)
        if [ -z "$VIKUNJA_DIRECT" ] || [ -z "$JAQ" ]; then
          exit 0
        fi

        # Skip sync if we're already in a sync (prevents loops)
        [ -n "''${VIKUNJA_SYNC_RUNNING:-}" ] && exit 0

        # Check if this is a deletion (status changed to deleted)
        task_status=$(echo "$modified_json" | "$JAQ" -r '.status // empty')

        # Background the sync via setsid (fully detached from terminal/TW)
        # Uses timeout to prevent hung processes
        STATE_DIR="${stateDir}"
        setsid sh -c '
          export VIKUNJA_URL="${cfg.vikunjaUrl}"
          export VIKUNJA_USER="${cfg.caldavUser}"
          export VIKUNJA_API_TOKEN_FILE="${config.sops.secrets."caldav/vikunja-api".path}"
          export VIKUNJA_DEFAULT_PROJECT="${cfg.defaultProject}"

          mkdir -p "$7"

          # If task was deleted, use delete-hook command; otherwise use regular hook
          if [ "$5" = "deleted" ]; then
            timeout 30 sh -c "echo \"\$1\" | \"\$2\" delete-hook" _ "$2" "$3" >> "$7/direct.log" 2>&1
            exit_code=$?
          else
            # Use separate echo commands piped to ensure proper newlines between JSON lines
            timeout 30 sh -c "{ echo \"\$1\"; echo \"\$2\"; } | \"\$3\" hook" _ "$1" "$2" "$3" >> "$7/direct.log" 2>&1
            exit_code=$?
          fi

          # On failure, queue for retry
          if [ $exit_code -ne 0 ]; then
            uuid=$(echo "$2" | "$4" -r ".uuid // empty")
            [ -n "$uuid" ] && echo "$uuid" >> "$7/queue.txt"
          fi
          ${lib.optionalString cfg.enableTaskChampionSync ''
          # TaskChampion sync (async, non-blocking)
          timeout 30 "$6" sync >> "$7/taskchampion-sync.log" 2>&1 || true
          ''}
        ' _ "$original_json" "$modified_json" "$VIKUNJA_DIRECT" "$JAQ" "$task_status" "$TASK" "$STATE_DIR" </dev/null >/dev/null 2>&1 &

        exit 0
      '';
    };

    # NOTE: TaskWarrior has NO on-delete hook. Deletion triggers on-modify with status:deleted.
    # The on-modify hook above handles deletion by checking for status:deleted.

    # Fallback on-exit hook for when direct sync is disabled
    environment.etc."vikunja-sync-hook/on-exit-vikunja" = lib.mkIf (!cfg.enableDirectSync) {
      mode = "0755";
      text = ''
        #!/bin/sh
        # Taskwarrior on-exit hook - trigger full sync (fallback mode)

        # Ensure system binaries are in PATH
        PATH="/run/current-system/sw/bin:$PATH"
        export PATH

        SYSTEMCTL=$(command -v systemctl) || true

        [ -n "''${VIKUNJA_SYNC_RUNNING:-}" ] && exit 0
        cat > /dev/null

        # Fail-open if systemctl not found
        [ -z "$SYSTEMCTL" ] && exit 0

        "$SYSTEMCTL" --user start vikunja-sync.service --no-block 2>/dev/null || true
        exit 0
      '';
    };

    # Activation script to symlink hook with validation
    system.activationScripts.vikunja-sync-hook = {
      text =
        if cfg.enableDirectSync
        then ''
          HOOK_DIR="${homeDir}/.config/task/hooks"
          mkdir -p "$HOOK_DIR"

          # Remove old/unused hooks
          rm -f "$HOOK_DIR/on-exit-vikunja"
          rm -f "$HOOK_DIR/on-delete-vikunja"  # TW has no on-delete hook; deletion handled by on-modify

          # Install on-add and on-modify hooks for direct sync
          ln -sf /etc/vikunja-sync-hook/on-add-vikunja "$HOOK_DIR/on-add-vikunja"
          ln -sf /etc/vikunja-sync-hook/on-modify-vikunja "$HOOK_DIR/on-modify-vikunja"
          chown -h ${username}:users "$HOOK_DIR/on-add-vikunja" "$HOOK_DIR/on-modify-vikunja"

          # Validate hooks are correctly linked and executable
          ERRORS=0
          for hook in on-add-vikunja on-modify-vikunja; do
            TARGET=$(readlink -f "$HOOK_DIR/$hook" 2>/dev/null)
            if [ ! -x "$TARGET" ]; then
              echo "vikunja-sync: WARNING - Hook $hook not executable or missing: $TARGET" >&2
              ERRORS=$((ERRORS + 1))
            fi
          done

          # Check if vikunja-direct is in PATH
          if ! command -v vikunja-direct >/dev/null 2>&1; then
            echo "vikunja-sync: WARNING - vikunja-direct not found in PATH" >&2
            ERRORS=$((ERRORS + 1))
          fi

          if [ $ERRORS -gt 0 ]; then
            echo "vikunja-sync: $ERRORS validation warning(s) - run 'vikunja-direct diagnose' for details" >&2
          fi
        ''
        else ''
          HOOK_DIR="${homeDir}/.config/task/hooks"
          mkdir -p "$HOOK_DIR"
          rm -f "$HOOK_DIR/on-add-vikunja" "$HOOK_DIR/on-modify-vikunja" "$HOOK_DIR/on-delete-vikunja"
          ln -sf /etc/vikunja-sync-hook/on-exit-vikunja "$HOOK_DIR/on-exit-vikunja"
          chown -h ${username}:users "$HOOK_DIR/on-exit-vikunja"
        '';
      deps = [];
    };

    # Self-test service runs diagnostics at login
    systemd.user.services.vikunja-sync-selftest = lib.mkIf cfg.enableDirectSync {
      description = "Vikunja Sync Self-Test";
      wantedBy = ["default.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Run diagnose but don't fail service on errors (just log)
        ExecStart = "${pkgs.bash}/bin/bash -c '${vikunjaSync}/bin/vikunja-direct diagnose 2>&1 | head -50 || true'";
      };

      environment = {
        VIKUNJA_URL = cfg.vikunjaUrl;
        VIKUNJA_USER = cfg.caldavUser;
        VIKUNJA_API_TOKEN_FILE = config.sops.secrets."caldav/vikunja-api".path;
      };
    };
  };
}
