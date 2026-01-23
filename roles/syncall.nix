# Syncall role - bi-directional sync between Taskwarrior and multiple CalDAV servers
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.roles.syncall;
  syncallPkg = pkgs.callPackage ../pkgs/syncall/default.nix {};
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
        default = 15;
        description = "Sync interval in minutes";
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
    # Add syncall and wrapper scripts to system packages
    environment.systemPackages = [
      syncallPkg
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

    # Taskwarrior on-exit hook - triggers all sync services
    environment.etc."syncall-task-hook/on-exit-syncall" = {
      mode = "0755";
      text = ''
        #!${pkgs.bash}/bin/bash
        # Taskwarrior on-exit hook - trigger async sync to all CalDAV targets

        if [ -z "''${SYNCALL_RUNNING:-}" ]; then
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: _: ''
            ${pkgs.systemd}/bin/systemctl --user start ${serviceName name}.service --no-block 2>/dev/null || true
          '') enabledTargets)}
        fi

        exit 0
      '';
    };

    # Activation script to symlink hook
    system.activationScripts.syncall-hook = {
      text = ''
        HOOK_DIR="${homeDir}/.config/task/hooks"
        mkdir -p "$HOOK_DIR"
        ln -sf /etc/syncall-task-hook/on-exit-syncall "$HOOK_DIR/on-exit-syncall"
        chown -h ${username}:users "$HOOK_DIR/on-exit-syncall"
      '';
      deps = [];
    };
  };
}
