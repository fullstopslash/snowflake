# Vikunja webhook receiver role - direct-write sync on task changes
#
# Architecture: Webhook payload -> vikunja-direct webhook -> TW import
# Target latency: <100ms (vs ~2000ms with full sync)
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.roles.vikunjaWebhook;
  username = config.hostSpec.primaryUser;
  homeDir = config.users.users.${username}.home;

  # Get vikunja-sync config from the sync role
  syncCfg = config.roles.vikunjaSync;

  # Direct-write handler package
  vikunjaDirectPkg = pkgs.callPackage ../pkgs/vikunja-sync/default.nix {};

  # Queue directory for webhook payloads (user-writable for cleanup)
  queueDir = "/run/vikunja-webhook";

  # Direct webhook handler - writes payload to queue, triggers user service
  # No sudo - uses machinectl to trigger user service that reads from queue
  triggerScript = pkgs.writeShellScript "trigger-vikunja-direct" ''
    set -euo pipefail

    # Webhook passes payload file via PAYLOAD env var (from pass-file-to-command)
    PAYLOAD_FILE="''${PAYLOAD:-''${1:-}}"

    if [[ -z "$PAYLOAD_FILE" || ! -f "$PAYLOAD_FILE" ]]; then
      echo "ERROR: No payload file provided" >&2
      exit 1
    fi

    # Log with timestamp
    echo "$(date -Iseconds) Vikunja webhook received"

    # Copy payload to queue directory (user-owned so user service can delete it)
    QUEUE_FILE="${queueDir}/$(date +%s%N).json"
    cp "$PAYLOAD_FILE" "$QUEUE_FILE"
    chown ${username}:users "$QUEUE_FILE"
    chmod 644 "$QUEUE_FILE"

    # Trigger user service to process the payload
    ${pkgs.systemd}/bin/machinectl shell ${username}@.host \
      /run/current-system/sw/bin/systemctl --user start vikunja-webhook-process@"$(basename "$QUEUE_FILE")" --no-block

    echo "Queued: $QUEUE_FILE"
  '';

  # JSON config for webhook - passes full payload via file
  hooksJson = builtins.toJSON [{
    id = "vikunja-sync";
    execute-command = toString triggerScript;
    command-working-directory = "/tmp";
    response-message = "Sync triggered";
    # Pass full payload as file (more reliable than args for large JSON)
    pass-file-to-command = [
      {
        source = "entire-payload";
        envname = "PAYLOAD";
      }
    ];
    trigger-rule = {
      "and" = [
        {
          match = {
            type = "payload-hmac-sha256";
            secret = "\${WEBHOOK_SECRET}";
            parameter = {
              source = "header";
              name = "X-Vikunja-Signature";
            };
          };
        }
        {
          "or" = [
            {
              match = {
                type = "value";
                value = "task.created";
                parameter = {
                  source = "payload";
                  name = "event_name";
                };
              };
            }
            {
              match = {
                type = "value";
                value = "task.updated";
                parameter = {
                  source = "payload";
                  name = "event_name";
                };
              };
            }
            {
              match = {
                type = "value";
                value = "task.deleted";
                parameter = {
                  source = "payload";
                  name = "event_name";
                };
              };
            }
          ];
        }
      ];
    };
  }];
in {
  options.roles.vikunjaWebhook = {
    enable = lib.mkEnableOption "Vikunja webhook receiver";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9000;
      description = "Port for webhook receiver";
    };
  };

  config = lib.mkIf cfg.enable {
    # SOPS secret for webhook HMAC validation
    # Note: caldav/vikunja-api is defined in vikunja-sync.nix
    sops.secrets."webhook/vikunja" = {
      key = "webhook/vikunja";
      owner = "root";
      mode = "0600";
    };

    # Template hooks.json with secret injected
    sops.templates."vikunja-hooks.json" = {
      content = builtins.replaceStrings
        ["\${WEBHOOK_SECRET}"]
        [config.sops.placeholder."webhook/vikunja"]
        hooksJson;
      owner = "root";
      mode = "0600";
    };

    # Queue directory for webhook payloads (user-writable for cleanup)
    systemd.tmpfiles.rules = [
      "d ${queueDir} 0777 root root -"
    ];

    # Webhook receiver service (root, validates HMAC)
    systemd.services.vikunja-webhook = {
      description = "Vikunja webhook receiver (direct-write)";
      after = ["network.target" "sops-nix.service"];
      wants = ["sops-nix.service"];
      wantedBy = ["multi-user.target"];
      restartIfChanged = true;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.webhook}/bin/webhook -hooks ${config.sops.templates."vikunja-hooks.json".path} -ip [::] -port ${toString cfg.port} -verbose";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # User service template to process webhook payloads
    systemd.user.services."vikunja-webhook-process@" = {
      description = "Process Vikunja webhook payload %i";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${vikunjaDirectPkg}/bin/vikunja-direct webhook ${queueDir}/%i";
        ExecStartPost = "${pkgs.coreutils}/bin/rm -f ${queueDir}/%i";
      };
      environment = {
        VIKUNJA_URL = syncCfg.vikunjaUrl;
        VIKUNJA_USER = syncCfg.caldavUser;
        VIKUNJA_API_TOKEN_FILE = config.sops.secrets."caldav/vikunja-api".path;
      };
      # Include bash for TW hooks that use #!/usr/bin/env bash
      path = [pkgs.taskwarrior3 pkgs.bash pkgs.coreutils];
    };

    # Open port on Tailscale interface only
    networking.firewall.interfaces."tailscale0".allowedTCPPorts = [cfg.port];
  };
}
