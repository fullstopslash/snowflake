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

  # Script to process failed sync queue
  processQueueScript = pkgs.writeShellScript "vikunja-process-queue" ''
    QUEUE_FILE="/tmp/vikunja-sync-queue.txt"
    [[ ! -f "$QUEUE_FILE" ]] && exit 0

    export VIKUNJA_URL="${cfg.vikunjaUrl}"
    export VIKUNJA_USER="${cfg.caldavUser}"
    export VIKUNJA_API_TOKEN_FILE="${config.sops.secrets."caldav/vikunja-api".path}"
    export VIKUNJA_SYNC_RUNNING=1

    # Process unique UUIDs from queue
    sort -u "$QUEUE_FILE" | while read -r uuid; do
      [[ -z "$uuid" ]] && continue
      echo "[$(date -Iseconds)] Retrying sync for $uuid" >> /tmp/vikunja-direct.log
      ${vikunjaSync}/bin/vikunja-direct push "$uuid" 2>> /tmp/vikunja-direct.log && \
        sed -i "/^$uuid$/d" "$QUEUE_FILE"
    done

    # Clean up empty queue file
    [[ ! -s "$QUEUE_FILE" ]] && rm -f "$QUEUE_FILE"
  '';

  # Script to sync a specific project (used by reconciliation)
  syncProjectScript = pkgs.writeShellScript "vikunja-sync-project" ''
    PROJECT="$1"
    if [[ -z "$PROJECT" ]]; then
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
      "d /tmp/vikunja-sync 1777 root root -"
    ];

    # NetworkManager dispatcher - process queue and reconcile on network-up
    networking.networkmanager.dispatcherScripts = lib.mkIf cfg.enableDirectSync [
      {
        source = pkgs.writeShellScript "vikunja-network-up" ''
          [[ "$2" != "up" ]] && exit 0

          # Wait for network to stabilize
          sleep 2

          # Process any queued failed syncs (as user)
          ${pkgs.sudo}/bin/sudo -u ${username} ${processQueueScript} &

          # Check if we need reconciliation (offline > 30 min)
          LAST_SYNC="/tmp/vikunja-last-sync"
          NOW=$(date +%s)
          if [[ -f "$LAST_SYNC" ]]; then
            LAST=$(cat "$LAST_SYNC")
            OFFLINE_SEC=$((NOW - LAST))
            if [[ $OFFLINE_SEC -gt 1800 ]]; then
              echo "[$(date -Iseconds)] Offline for $((OFFLINE_SEC/60))min, triggering reconciliation" >> /tmp/vikunja-direct.log
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
      path = [pkgs.taskwarrior3 pkgs.curl pkgs.jq pkgs.yq-go pkgs.sops pkgs.bash pkgs.coreutils];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = syncAllScript;
      };
    };

    # On-demand reconciliation service (triggered by network-up after offline period)
    # Always available, independent of enableReconciliation timer setting
    systemd.user.services.vikunja-reconcile = lib.mkIf cfg.enableDirectSync {
      description = "Vikunja on-demand reconciliation (network recovery)";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      path = [pkgs.taskwarrior3 pkgs.curl pkgs.jq pkgs.yq-go pkgs.sops pkgs.bash pkgs.coreutils];
      serviceConfig = {
        Type = "oneshot";
        # Debounce: don't run if already ran recently
        ExecCondition = "${pkgs.bash}/bin/bash -c 'test ! -f /tmp/vikunja-reconcile.lock || test $(($(date +%%s) - $(stat -c %%Y /tmp/vikunja-reconcile.lock))) -gt 300'";
      };
      script = ''
        touch /tmp/vikunja-reconcile.lock
        echo "[$(date -Iseconds)] Starting reconciliation" >> /tmp/vikunja-direct.log

        # First, process the queue
        ${processQueueScript}

        # Then run full sync
        ${syncAllScript}

        echo "[$(date -Iseconds)] Reconciliation complete" >> /tmp/vikunja-direct.log
      '';
    };

    # Per-project sync service (triggered by webhook or hook)
    systemd.user.services.vikunja-sync-project = {
      description = "Vikunja per-project sync";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      path = [pkgs.taskwarrior3 pkgs.curl pkgs.jq pkgs.yq-go pkgs.sops pkgs.bash pkgs.coreutils];
      serviceConfig = {
        Type = "oneshot";
      };
      # Project name passed via VIKUNJA_SYNC_PROJECT env var
      script = ''
        if [[ -z "''${VIKUNJA_SYNC_PROJECT:-}" ]]; then
          echo "VIKUNJA_SYNC_PROJECT not set, running full sync"
          exec ${syncAllScript}
        fi
        exec ${syncProjectScript} "$VIKUNJA_SYNC_PROJECT"
      '';
    };

    # Taskwarrior on-add hook - direct push to Vikunja API (instant sync for new tasks)
    # NON-BLOCKING: outputs task immediately, syncs in background
    environment.etc."vikunja-sync-hook/on-add-vikunja" = lib.mkIf cfg.enableDirectSync {
      mode = "0755";
      text = ''
        #!${pkgs.bash}/bin/bash
        # Taskwarrior on-add hook - non-blocking push to Vikunja
        # Outputs task immediately, syncs in background for <10ms latency

        # Read the new task JSON
        read -r task_json

        # Output immediately so TW can continue (CRITICAL for responsiveness)
        echo "$task_json"

        # Skip sync if we're already in a sync (prevents loops)
        [[ -n "''${VIKUNJA_SYNC_RUNNING:-}" ]] && exit 0

        # Background the sync via setsid (fully detached from terminal/TW)
        setsid ${pkgs.bash}/bin/bash -c '
          export VIKUNJA_URL="${cfg.vikunjaUrl}"
          export VIKUNJA_USER="${cfg.caldavUser}"
          export VIKUNJA_API_TOKEN_FILE="${config.sops.secrets."caldav/vikunja-api".path}"

          echo "$1" | ${vikunjaSync}/bin/vikunja-direct hook >> /tmp/vikunja-direct.log 2>&1

          # On failure, queue for retry
          if [[ $? -ne 0 ]]; then
            uuid=$(echo "$1" | ${pkgs.jq}/bin/jq -r ".uuid // empty")
            [[ -n "$uuid" ]] && echo "$uuid" >> /tmp/vikunja-sync-queue.txt
          fi
        ' _ "$task_json" </dev/null >/dev/null 2>&1 &

        exit 0
      '';
    };

    # Taskwarrior on-modify hook - direct push to Vikunja API (instant sync)
    # NON-BLOCKING: outputs task immediately, syncs in background
    environment.etc."vikunja-sync-hook/on-modify-vikunja" = lib.mkIf cfg.enableDirectSync {
      mode = "0755";
      text = ''
        #!${pkgs.bash}/bin/bash
        # Taskwarrior on-modify hook - non-blocking push to Vikunja
        # Outputs modified task immediately, syncs in background for <10ms latency

        # Read original and modified task JSON
        read -r original_json
        read -r modified_json

        # Output modified task immediately so TW can continue (CRITICAL)
        echo "$modified_json"

        # Skip sync if we're already in a sync (prevents loops)
        [[ -n "''${VIKUNJA_SYNC_RUNNING:-}" ]] && exit 0

        # Background the sync via setsid (fully detached from terminal/TW)
        setsid ${pkgs.bash}/bin/bash -c '
          export VIKUNJA_URL="${cfg.vikunjaUrl}"
          export VIKUNJA_USER="${cfg.caldavUser}"
          export VIKUNJA_API_TOKEN_FILE="${config.sops.secrets."caldav/vikunja-api".path}"

          printf "%s\n%s\n" "$1" "$2" | ${vikunjaSync}/bin/vikunja-direct hook >> /tmp/vikunja-direct.log 2>&1

          # On failure, queue for retry
          if [[ $? -ne 0 ]]; then
            uuid=$(echo "$2" | ${pkgs.jq}/bin/jq -r ".uuid // empty")
            [[ -n "$uuid" ]] && echo "$uuid" >> /tmp/vikunja-sync-queue.txt
          fi
        ' _ "$original_json" "$modified_json" </dev/null >/dev/null 2>&1 &

        exit 0
      '';
    };

    # Fallback on-exit hook for when direct sync is disabled
    environment.etc."vikunja-sync-hook/on-exit-vikunja" = lib.mkIf (!cfg.enableDirectSync) {
      mode = "0755";
      text = ''
        #!${pkgs.bash}/bin/bash
        # Taskwarrior on-exit hook - trigger full sync (fallback mode)

        [[ -n "''${VIKUNJA_SYNC_RUNNING:-}" ]] && exit 0
        cat > /dev/null
        ${pkgs.systemd}/bin/systemctl --user start vikunja-sync.service --no-block 2>/dev/null || true
        exit 0
      '';
    };

    # Activation script to symlink hook
    system.activationScripts.vikunja-sync-hook = {
      text =
        if cfg.enableDirectSync
        then ''
          HOOK_DIR="${homeDir}/.config/task/hooks"
          mkdir -p "$HOOK_DIR"
          # Remove old on-exit hook if exists
          rm -f "$HOOK_DIR/on-exit-vikunja"
          # Install on-add and on-modify hooks for direct sync
          ln -sf /etc/vikunja-sync-hook/on-add-vikunja "$HOOK_DIR/on-add-vikunja"
          ln -sf /etc/vikunja-sync-hook/on-modify-vikunja "$HOOK_DIR/on-modify-vikunja"
          chown -h ${username}:users "$HOOK_DIR/on-add-vikunja" "$HOOK_DIR/on-modify-vikunja"
        ''
        else ''
          HOOK_DIR="${homeDir}/.config/task/hooks"
          mkdir -p "$HOOK_DIR"
          rm -f "$HOOK_DIR/on-add-vikunja" "$HOOK_DIR/on-modify-vikunja"
          ln -sf /etc/vikunja-sync-hook/on-exit-vikunja "$HOOK_DIR/on-exit-vikunja"
          chown -h ${username}:users "$HOOK_DIR/on-exit-vikunja"
        '';
      deps = [];
    };
  };
}
