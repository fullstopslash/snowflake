# Vikunja webhook receiver role - triggers vikunja-sync on task changes
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.roles.vikunjaWebhook;
  username = config.hostSpec.primaryUser;

  # Get vikunja-sync config from the sync role
  syncCfg = config.roles.vikunjaSync;

  # Script to trigger vikunja-sync for a specific project
  # Receives project title directly from webhook payload
  triggerScript = pkgs.writeShellScript "trigger-vikunja-sync" ''
    PROJECT_TITLE="''${1:-}"

    echo "$(date -Iseconds) Vikunja webhook received for project: $PROJECT_TITLE"

    # Environment variables for vikunja-sync (including label sync)
    SYNC_ENV="VIKUNJA_URL=${syncCfg.vikunjaUrl}"
    SYNC_ENV="$SYNC_ENV VIKUNJA_USER=${syncCfg.caldavUser}"
    SYNC_ENV="$SYNC_ENV VIKUNJA_API_TOKEN_FILE=${config.sops.secrets."caldav/vikunja-api".path}"
    SYNC_ENV="$SYNC_ENV VIKUNJA_CALDAV_PASS_FILE=${config.sops.secrets."caldav/vikunja".path}"

    if [[ -n "$PROJECT_TITLE" && "$PROJECT_TITLE" != "null" ]]; then
      # Sync specific project with environment variables
      ${pkgs.systemd}/bin/machinectl shell ${username}@.host \
        ${pkgs.systemd}/bin/systemd-run --user --collect --no-block \
        --unit=vikunja-sync-webhook \
        /usr/bin/env $SYNC_ENV \
        /run/current-system/sw/bin/vikunja-sync project "$PROJECT_TITLE"
    else
      # No project title, run full sync via service (which sets its own env)
      ${pkgs.systemd}/bin/machinectl shell ${username}@.host \
        ${pkgs.systemd}/bin/systemctl --user start vikunja-sync.service --no-block
    fi
  '';

  # JSON config for webhook - uses sops placeholder for HMAC secret
  # Extracts project title from payload (data.project.title)
  hooksJson = builtins.toJSON [{
    id = "vikunja-sync";
    execute-command = toString triggerScript;
    command-working-directory = "/tmp";
    response-message = "Sync triggered";
    pass-arguments-to-command = [
      {
        source = "payload";
        name = "data.project.title";
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
    # SOPS secret for HMAC validation
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

    # Webhook receiver service
    systemd.services.vikunja-webhook = {
      description = "Vikunja webhook receiver";
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

    # Open port on Tailscale interface only
    networking.firewall.interfaces."tailscale0".allowedTCPPorts = [cfg.port];
  };
}
