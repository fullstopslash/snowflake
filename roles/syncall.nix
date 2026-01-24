# Syncall role - bi-directional sync between Taskwarrior and multiple CalDAV servers
#
# Architecture:
#   TW -> CalDAV: Direct writes via on-modify hook (<200ms)
#   CalDAV -> TW: Periodic sync (CalDAV doesn't support webhooks)
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.roles.syncall;
  syncallPkg = pkgs.callPackage ../pkgs/syncall/default.nix {};
  caldavDirectPkg = pkgs.callPackage ../pkgs/caldav-direct/default.nix {};
  username = config.hostSpec.primaryUser;
  homeDir = config.users.users.${username}.home;

  # Submodule for each CalDAV target
  targetModule = {name, ...}: {
    options = {
      enable = lib.mkEnableOption "this CalDAV target" // {default = true;};

      caldavUrl = lib.mkOption {
        type = lib.types.str;
        description = "CalDAV server URL";
      };

      caldavUser = lib.mkOption {
        type = lib.types.str;
        default = "rain";
        description = "CalDAV username";
      };

      caldavCalendar = lib.mkOption {
        type = lib.types.str;
        default = "Tasks";
        description = "CalDAV calendar name for tasks";
      };

      secretKey = lib.mkOption {
        type = lib.types.str;
        description = "SOPS secret key path (e.g., caldav/nextcloud)";
      };

      syncInterval = lib.mkOption {
        type = lib.types.int;
        default = 60;
        description = "Reconciliation sync interval in minutes (CalDAV -> TW direction)";
      };

      resolutionStrategy = lib.mkOption {
        type = lib.types.enum ["MostRecentRS" "AlwaysFirstRS" "AlwaysSecondRS"];
        default = "MostRecentRS";
        description = "Conflict resolution strategy";
      };
    };
  };

  # Filter to only enabled targets
  enabledTargets = lib.filterAttrs (_: t: t.enable) cfg.targets;

  # Generate service name from target name
  serviceName = name: "syncall-${name}";

  # Generate password file path from target name
  passwordFile = name: "${homeDir}/.config/syncall/.caldav-password-${name}";

  # Generate lock file path from target name
  lockFile = name: "/tmp/syncall-${name}.lock";

  # Script to process failed CalDAV sync queue for a target
  processQueueScript = name: target: pkgs.writeShellScript "caldav-process-queue-${name}" ''
    QUEUE_FILE="/tmp/caldav-sync-queue-${name}.txt"
    [[ ! -f "$QUEUE_FILE" ]] && exit 0

    export CALDAV_URL="${target.caldavUrl}"
    export CALDAV_USER="${target.caldavUser}"
    export CALDAV_PASS_FILE="${passwordFile name}"
    export CALDAV_CALENDAR="${target.caldavCalendar}"
    export SYNCALL_RUNNING=1

    # Process unique UUIDs from queue
    sort -u "$QUEUE_FILE" | while read -r uuid; do
      [[ -z "$uuid" ]] && continue
      echo "[$(date -Iseconds)] Retrying CalDAV sync for $uuid" >> /tmp/caldav-direct-${name}.log
      ${caldavDirectPkg}/bin/caldav-direct push "$uuid" 2>> /tmp/caldav-direct-${name}.log && \
        sed -i "/^$uuid$/d" "$QUEUE_FILE"
    done

    # Clean up empty queue file
    [[ ! -s "$QUEUE_FILE" ]] && rm -f "$QUEUE_FILE"
  '';
in {
  options.roles.syncall = {
    enable = lib.mkEnableOption "Syncall TaskWarrior-CalDAV sync";

    targets = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule targetModule);
      default = {};
      description = "CalDAV targets to sync with";
      example = lib.literalExpression ''
        {
          nextcloud = {
            caldavUrl = "https://nextcloud.example.com/remote.php/dav";
            caldavCalendar = "Tasks";
            secretKey = "caldav/nextcloud";
          };
          vikunja = {
            caldavUrl = "https://vikunja.example.com/dav/principals/user/";
            caldavCalendar = "tasks";
            secretKey = "caldav/vikunja";
          };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Add syncall, caldav-direct, and wrapper scripts to system packages
    environment.systemPackages = [
      syncallPkg
      caldavDirectPkg
      # tw-sync: trigger all syncs manually
      (pkgs.writeShellScriptBin "tw-sync" ''
        export SYNCALL_RUNNING=1
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: _: ''
          echo "=== Syncing ${name} ==="
          systemctl --user start ${serviceName name}.service
          journalctl --user -u ${serviceName name}.service -n 10 --no-pager
        '') enabledTargets)}
      '')
    ];

    # SOPS secrets for each CalDAV target
    sops.secrets = lib.mapAttrs' (name: target: {
      name = target.secretKey;
      value = {
        key = target.secretKey;
        path = passwordFile name;
        owner = username;
        group = "users";
        mode = "0600";
      };
    }) enabledTargets;

    # Ensure config directories exist
    systemd.tmpfiles.rules = [
      "d ${homeDir}/.config/syncall 0750 ${username} users -"
      "d ${homeDir}/.config/task/hooks 0750 ${username} users -"
    ];

    # NetworkManager dispatcher - process CalDAV queues on network-up
    networking.networkmanager.dispatcherScripts = [
      {
        source = pkgs.writeShellScript "caldav-network-up" ''
          [[ "$2" != "up" ]] && exit 0
          sleep 2

          # Process queued failed syncs for each CalDAV target
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: target: ''
            ${pkgs.sudo}/bin/sudo -u ${username} ${processQueueScript name target} &
          '') enabledTargets)}
        '';
        type = "basic";
      }
    ];

    # Systemd user timers for each target
    systemd.user.timers = lib.mapAttrs' (name: target: {
      name = serviceName name;
      value = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "${toString target.syncInterval}min";
          Persistent = true;
        };
      };
    }) enabledTargets;

    # Systemd user services for each target
    systemd.user.services = lib.mapAttrs' (name: target: {
      name = serviceName name;
      value = {
        description = "Sync Taskwarrior with CalDAV (${name})";
        after = ["network-online.target"];
        wants = ["network-online.target"];
        path = [pkgs.taskwarrior3 pkgs.bash];
        serviceConfig = {
          Type = "oneshot";
          ExecCondition = "${pkgs.bash}/bin/bash -c 'test ! -f ${lockFile name} || test $(( $(date +%%s) - $(stat -c %%Y ${lockFile name}) )) -gt 30'";
        };
        script = ''
          set -euo pipefail
          PASSWORD_FILE="${passwordFile name}"

          if [ ! -r "$PASSWORD_FILE" ]; then
            echo "CalDAV password file not found: $PASSWORD_FILE"
            exit 1
          fi

          touch "${lockFile name}"
          touch "${homeDir}/.config/task/sync.conf"

          ${syncallPkg}/bin/tw_caldav_sync \
            --caldav-url "${target.caldavUrl}" \
            --caldav-user "${target.caldavUser}" \
            --caldav-passwd-cmd "cat $PASSWORD_FILE" \
            --caldav-calendar "${target.caldavCalendar}" \
            --resolution-strategy ${target.resolutionStrategy} \
            --all \
            || true

          rm -f "${lockFile name}"
        '';
      };
    }) enabledTargets;

    # Taskwarrior hooks - direct CalDAV writes for each target
    # NON-BLOCKING: Each hook outputs immediately, syncs in background
    environment.etc = lib.mkMerge [
      # on-add hooks
      (lib.mapAttrs' (name: target: {
        name = "syncall-task-hook/on-add-caldav-${name}";
        value = {
          mode = "0755";
          text = ''
            #!${pkgs.bash}/bin/bash
            # Taskwarrior on-add hook - non-blocking push to CalDAV (${name})
            # Outputs task immediately, syncs in background for <10ms latency

            # Read the new task JSON
            read -r task_json

            # Output immediately so TW can continue (CRITICAL for responsiveness)
            echo "$task_json"

            # Skip if we're running a sync (prevent loops)
            [[ -n "''${SYNCALL_RUNNING:-}" ]] && exit 0

            # Background the sync via setsid (fully detached from terminal/TW)
            setsid ${pkgs.bash}/bin/bash -c '
              export CALDAV_URL="${target.caldavUrl}"
              export CALDAV_USER="${target.caldavUser}"
              export CALDAV_PASS_FILE="${passwordFile name}"
              export CALDAV_CALENDAR="${target.caldavCalendar}"

              echo "$1" | ${caldavDirectPkg}/bin/caldav-direct hook >> /tmp/caldav-direct-${name}.log 2>&1

              # On failure, queue for retry
              if [[ $? -ne 0 ]]; then
                uuid=$(echo "$1" | ${pkgs.jq}/bin/jq -r ".uuid // empty")
                [[ -n "$uuid" ]] && echo "$uuid" >> /tmp/caldav-sync-queue-${name}.txt
              fi
            ' _ "$task_json" </dev/null >/dev/null 2>&1 &

            exit 0
          '';
        };
      }) enabledTargets)
      # on-modify hooks
      (lib.mapAttrs' (name: target: {
        name = "syncall-task-hook/on-modify-caldav-${name}";
        value = {
          mode = "0755";
          text = ''
            #!${pkgs.bash}/bin/bash
            # Taskwarrior on-modify hook - non-blocking push to CalDAV (${name})
            # Outputs modified task immediately, syncs in background for <10ms latency

            # Read original and modified task JSON
            read -r original_json
            read -r modified_json

            # Output modified task immediately so TW can continue (CRITICAL)
            echo "$modified_json"

            # Skip if we're running a sync (prevent loops)
            [[ -n "''${SYNCALL_RUNNING:-}" ]] && exit 0

            # Background the sync via setsid (fully detached from terminal/TW)
            setsid ${pkgs.bash}/bin/bash -c '
              export CALDAV_URL="${target.caldavUrl}"
              export CALDAV_USER="${target.caldavUser}"
              export CALDAV_PASS_FILE="${passwordFile name}"
              export CALDAV_CALENDAR="${target.caldavCalendar}"

              printf "%s\n%s\n" "$1" "$2" | ${caldavDirectPkg}/bin/caldav-direct hook >> /tmp/caldav-direct-${name}.log 2>&1

              # On failure, queue for retry
              if [[ $? -ne 0 ]]; then
                uuid=$(echo "$2" | ${pkgs.jq}/bin/jq -r ".uuid // empty")
                [[ -n "$uuid" ]] && echo "$uuid" >> /tmp/caldav-sync-queue-${name}.txt
              fi
            ' _ "$original_json" "$modified_json" </dev/null >/dev/null 2>&1 &

            exit 0
          '';
        };
      }) enabledTargets)
    ];

    # Activation script to symlink hooks
    system.activationScripts.syncall-hook = {
      text = ''
        HOOK_DIR="${homeDir}/.config/task/hooks"
        mkdir -p "$HOOK_DIR"
        # Remove old on-exit hook if present
        rm -f "$HOOK_DIR/on-exit-syncall"
        # Symlink on-add and on-modify hooks for each CalDAV target
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: _: ''
          ln -sf /etc/syncall-task-hook/on-add-caldav-${name} "$HOOK_DIR/on-add-caldav-${name}"
          ln -sf /etc/syncall-task-hook/on-modify-caldav-${name} "$HOOK_DIR/on-modify-caldav-${name}"
          chown -h ${username}:users "$HOOK_DIR/on-add-caldav-${name}" "$HOOK_DIR/on-modify-caldav-${name}"
        '') enabledTargets)}
      '';
      deps = [];
    };
  };
}
