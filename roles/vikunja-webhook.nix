# Vikunja webhook receiver role - direct-write sync on task changes
#
# Architecture: Webhook payload -> vikunja-direct webhook -> TW import
# Target latency: <100ms (vs ~2000ms with full sync)
#
# Webhook provisioning: Automatically creates webhooks on all Vikunja projects
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

  # Webhook provisioning script - ensures webhooks exist on all projects
  provisionWebhooksScript = pkgs.writeShellScript "vikunja-provision-webhooks" ''
    set -euo pipefail

    VIKUNJA_URL="$1"
    API_TOKEN_FILE="$2"
    WEBHOOK_SECRET_FILE="$3"
    WEBHOOK_URL="$4"

    API_TOKEN=$(cat "$API_TOKEN_FILE")
    WEBHOOK_SECRET=$(cat "$WEBHOOK_SECRET_FILE")

    log() { echo "[$(date -Iseconds)] $*"; }

    # Get all non-archived projects
    PROJECTS=$(${pkgs.curl}/bin/curl -sf \
      -H "Authorization: Bearer $API_TOKEN" \
      "$VIKUNJA_URL/api/v1/projects" | ${pkgs.jq}/bin/jq -r '.[] | select(.is_archived == false) | .id')

    if [[ -z "$PROJECTS" ]]; then
      log "No projects found or API error"
      exit 1
    fi

    for PROJECT_ID in $PROJECTS; do
      # Check if webhook already exists for this project
      EXISTING=$(${pkgs.curl}/bin/curl -sf \
        -H "Authorization: Bearer $API_TOKEN" \
        "$VIKUNJA_URL/api/v1/projects/$PROJECT_ID/webhooks" | \
        ${pkgs.jq}/bin/jq -r --arg url "$WEBHOOK_URL" '.[] | select(.target_url == $url) | .id')

      if [[ -n "$EXISTING" ]]; then
        # Check if existing webhook has the secret set
        HAS_SECRET=$(${pkgs.curl}/bin/curl -sf \
          -H "Authorization: Bearer $API_TOKEN" \
          "$VIKUNJA_URL/api/v1/projects/$PROJECT_ID/webhooks" | \
          ${pkgs.jq}/bin/jq -r --arg url "$WEBHOOK_URL" '.[] | select(.target_url == $url) | .secret')

        if [[ -z "$HAS_SECRET" ]]; then
          # Vikunja doesn't support updating webhook secrets - must delete and recreate
          ${pkgs.curl}/bin/curl -sf -X DELETE \
            -H "Authorization: Bearer $API_TOKEN" \
            "$VIKUNJA_URL/api/v1/projects/$PROJECT_ID/webhooks/$EXISTING" > /dev/null

          # Create new webhook with secret
          PAYLOAD=$(${pkgs.jq}/bin/jq -n \
            --arg url "$WEBHOOK_URL" \
            --arg secret "$WEBHOOK_SECRET" \
            '{target_url: $url, events: ["task.created", "task.updated", "task.deleted"], secret: $secret}')

          NEW_ID=$(${pkgs.curl}/bin/curl -sf -X PUT \
            -H "Authorization: Bearer $API_TOKEN" \
            -H "Content-Type: application/json" \
            "$VIKUNJA_URL/api/v1/projects/$PROJECT_ID/webhooks" \
            -d "$PAYLOAD" | ${pkgs.jq}/bin/jq -r '.id // "error"')

          log "Project $PROJECT_ID: recreated webhook with secret (old=$EXISTING, new=$NEW_ID)"
        else
          log "Project $PROJECT_ID: webhook already exists (id=$EXISTING)"
        fi
        continue
      fi

      # Create webhook (use jq to properly construct JSON with escaping)
      PAYLOAD=$(${pkgs.jq}/bin/jq -n \
        --arg url "$WEBHOOK_URL" \
        --arg secret "$WEBHOOK_SECRET" \
        '{target_url: $url, events: ["task.created", "task.updated", "task.deleted"], secret: $secret}')

      RESULT=$(${pkgs.curl}/bin/curl -sf -X PUT \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        "$VIKUNJA_URL/api/v1/projects/$PROJECT_ID/webhooks" \
        -d "$PAYLOAD" | ${pkgs.jq}/bin/jq -r '.id // "error"')

      if [[ "$RESULT" == "error" ]]; then
        log "Project $PROJECT_ID: failed to create webhook"
      else
        log "Project $PROJECT_ID: created webhook (id=$RESULT)"
      fi
    done

    log "Webhook provisioning complete"
  '';

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

    callbackHost = lib.mkOption {
      type = lib.types.str;
      description = "Host/IP that Vikunja can reach this webhook receiver at (e.g., Tailscale IP)";
      example = "100.77.72.15";
    };
  };

  config = lib.mkIf cfg.enable {
    # SOPS secret for webhook HMAC validation (root-owned for webhook service)
    # Note: caldav/vikunja-api is defined in vikunja-sync.nix
    sops.secrets."webhook/vikunja" = {
      key = "webhook/vikunja";
      owner = "root";
      mode = "0600";
    };

    # User-owned copy for provisioning service
    sops.secrets."webhook/vikunja-user" = {
      key = "webhook/vikunja";
      owner = username;
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

    # Webhook provisioning service - ensures webhooks exist on all projects
    systemd.user.services.vikunja-provision-webhooks = {
      description = "Provision Vikunja webhooks on all projects";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      path = [pkgs.curl pkgs.jq pkgs.coreutils];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${provisionWebhooksScript} ${syncCfg.vikunjaUrl} ${config.sops.secrets."caldav/vikunja-api".path} ${config.sops.secrets."webhook/vikunja-user".path} http://${cfg.callbackHost}:${toString cfg.port}/hooks/vikunja-sync";
      };
    };

    # Timer to run provisioning on boot and hourly (catches new projects)
    systemd.user.timers.vikunja-provision-webhooks = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "1h";
        Persistent = true;
      };
    };
  };
}
