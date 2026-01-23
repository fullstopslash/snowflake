# Vikunja sync role - bidirectional multi-project sync between Taskwarrior and Vikunja
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.roles.vikunjaSync;
  username = config.hostSpec.primaryUser;
  homeDir = config.users.users.${username}.home;

  vikunjaSync = pkgs.callPackage ../pkgs/vikunja-sync/default.nix {};

  # Script to sync a specific project (used by webhook and hook)
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

  # Script to sync all projects
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
      default = "https://vikunja.chimera-micro.ts.net";
      description = "Vikunja instance URL";
    };

    caldavUser = lib.mkOption {
      type = lib.types.str;
      default = "rain";
      description = "CalDAV/Vikunja username";
    };

    syncInterval = lib.mkOption {
      type = lib.types.int;
      default = 15;
      description = "Full sync interval in minutes";
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

    # Full sync timer (periodic)
    systemd.user.timers.vikunja-sync = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "${toString cfg.syncInterval}min";
        Persistent = true;
      };
    };

    # Full sync service
    systemd.user.services.vikunja-sync = {
      description = "Vikunja full bidirectional sync";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      path = [pkgs.taskwarrior3 pkgs.curl pkgs.jq pkgs.yq-go pkgs.sops pkgs.bash pkgs.coreutils];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = syncAllScript;
      };
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

    # Taskwarrior on-exit hook - triggers full sync with debouncing
    environment.etc."vikunja-sync-hook/on-exit-vikunja" = {
      mode = "0755";
      text = ''
        #!${pkgs.bash}/bin/bash
        # Taskwarrior on-exit hook - trigger Vikunja sync
        # Uses a single systemd unit to debounce rapid changes

        # Don't trigger if we're already in a sync
        [[ -n "''${VIKUNJA_SYNC_RUNNING:-}" ]] && exit 0

        # Drain stdin (required for on-exit hooks)
        cat > /dev/null

        # Trigger full sync via systemd - unit name provides natural debouncing
        # If unit is already running/starting, this is a no-op
        ${pkgs.systemd}/bin/systemctl --user start vikunja-sync.service --no-block 2>/dev/null || true

        exit 0
      '';
    };

    # Activation script to symlink hook
    system.activationScripts.vikunja-sync-hook = {
      text = ''
        HOOK_DIR="${homeDir}/.config/task/hooks"
        mkdir -p "$HOOK_DIR"
        ln -sf /etc/vikunja-sync-hook/on-exit-vikunja "$HOOK_DIR/on-exit-vikunja"
        chown -h ${username}:users "$HOOK_DIR/on-exit-vikunja"
      '';
      deps = [];
    };
  };
}
