# Bitwarden automation role
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.roles.bitwardenAutomation;
  sopsFolder = builtins.toString inputs.nix-secrets + "/sops";

  # Create a script that uses OAuth + libsecret (gnome-keyring) for full automation
  # This is the Hyprland-native approach instead of KDE Wallet
  bitwarden-autologin = pkgs.writeShellScript "bitwarden-autologin" ''
    #!/usr/bin/env sh
    set -eu

    echo "Starting Bitwarden OAuth + libsecret automation..."

    # Read secrets from SOPS - handle missing files gracefully
    SECRET_SERVER="${config.sops.secrets."bitwarden/server".path}"
    SECRET_EMAIL="${config.sops.secrets."bitwarden/user_email".path}"
    SECRET_CLIENT_ID="${config.sops.secrets."bitwarden/oauth_client_id".path}"
    SECRET_CLIENT_SECRET="${config.sops.secrets."bitwarden/oauth_client_secret".path}"

    # Check if secrets exist and are readable
    if [ ! -r "$SECRET_SERVER" ] || [ ! -r "$SECRET_EMAIL" ] || [ ! -r "$SECRET_CLIENT_ID" ] || [ ! -r "$SECRET_CLIENT_SECRET" ]; then
      echo "Bitwarden secrets not available yet (may be during rebuild), skipping..." 1>&2
      exit 0
    fi

    BW_SERVER=$(cat "$SECRET_SERVER")
    BW_USEREMAIL=$(cat "$SECRET_EMAIL")
    BITWARDEN_OAUTH_CLIENT_ID=$(cat "$SECRET_CLIENT_ID")
    BITWARDEN_OAUTH_CLIENT_SECRET=$(cat "$SECRET_CLIENT_SECRET")

    if [ -z "$BW_SERVER" ] || [ -z "$BW_USEREMAIL" ] || [ -z "$BITWARDEN_OAUTH_CLIENT_ID" ] || [ -z "$BITWARDEN_OAUTH_CLIENT_SECRET" ]; then
      echo "Bitwarden secrets are empty, skipping..." 1>&2
      exit 0
    fi

    # Configure bw if not already configured
    echo "Configuring bw..."
    ${pkgs.bitwarden-cli}/bin/bw config server "$BW_SERVER"

    # Check current status
    STATUS=$(${pkgs.bitwarden-cli}/bin/bw status --response | ${pkgs.jq}/bin/jq -r '.status')
    echo "Current status: $STATUS"

    case "$STATUS" in
      "unauthenticated")
        echo "Not logged in, authenticating with OAuth..."
        export BW_CLIENTID="$BITWARDEN_OAUTH_CLIENT_ID"
        export BW_CLIENTSECRET="$BITWARDEN_OAUTH_CLIENT_SECRET"

        # Use OAuth to authenticate
        if ${pkgs.bitwarden-cli}/bin/bw login --sso; then
          echo "Successfully authenticated via OAuth"
          STATUS="locked"
        else
          echo "Failed to authenticate via OAuth" 1>&2
          exit 1
        fi
        ;;
      "locked")
        echo "Logged in but locked, proceeding to unlock..."
        ;;
      "unlocked")
        echo "Already unlocked, checking if session is still valid..."
        # Test if current session works
        if ${pkgs.bitwarden-cli}/bin/bw list items --limit 1 >/dev/null 2>&1; then
          echo "Session is still valid, no action needed"
          exit 0
        else
          echo "Session expired, need to unlock again"
          STATUS="locked"
        fi
        ;;
      *)
        echo "Unknown status: $STATUS" 1>&2
        exit 1
        ;;
    esac

    # If we're locked, try to unlock using libsecret (gnome-keyring)
    if [ "$STATUS" = "locked" ]; then
      echo "Attempting to unlock using libsecret keyring..."

      # Try to get password from libsecret (gnome-keyring)
      STORED_PASSWORD=$(${pkgs.libsecret}/bin/secret-tool lookup service bitwarden attribute master-password 2>/dev/null || echo "")

      if [ -n "$STORED_PASSWORD" ]; then
        echo "Found stored password in keyring, attempting unlock..."
        export BW_PASSWORD="$STORED_PASSWORD"

        if ${pkgs.bitwarden-cli}/bin/bw unlock --passwordenv BW_PASSWORD; then
          echo "Successfully unlocked vault using stored password"

          # Test the session
          if ${pkgs.bitwarden-cli}/bin/bw list items --limit 1 >/dev/null 2>&1; then
            echo "Session established and working"
          else
            echo "Warning: Unlock succeeded but session test failed" 1>&2
            exit 1
          fi
        else
          echo "Stored password failed, falling back to manual unlock..."
          STATUS="locked"
        fi
      fi

      # If still locked, prompt user and store in keyring
      if [ "$STATUS" = "locked" ]; then
        echo "No stored password or stored password failed."
        echo "Please unlock manually with: bw unlock"
        echo ""
        echo "To store password for future use, run:"
        echo "echo 'your-master-password' | secret-tool store --label='Bitwarden Master Password' service bitwarden attribute master-password"
        exit 0
      fi
    fi
  '';

  # Create a simple sync script for rbw
  rbw-sync = pkgs.writeShellScript "rbw-sync" ''
    #!/usr/bin/env sh
    set -eu

    echo "Syncing rbw vault..."

    # Check if rbw is unlocked
    if ${pkgs.rbw}/bin/rbw unlocked; then
      echo "Syncing rbw vault..."
      if ${pkgs.rbw}/bin/rbw sync; then
        echo "rbw sync completed successfully"
      else
        echo "rbw sync failed" 1>&2
        exit 1
      fi
    else
      echo "rbw vault is locked, skipping sync"
      exit 0
    fi
  '';
in
{
  options.roles.bitwardenAutomation = {
    enable = lib.mkEnableOption "Enable Bitwarden automation";
    enableAutoLogin = lib.mkEnableOption "Enable automatic Bitwarden login on session start";
    syncInterval = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Sync interval in minutes for rbw";
    };
  };

  config = lib.mkIf cfg.enable {
    # Include required packages
    environment.systemPackages = with pkgs; [
      rbw
      bitwarden-cli
      jq
      libsecret # For secret-tool CLI (gnome-keyring integration)
    ];

    # SOPS secrets for Bitwarden automation
    # Secret names use slash path format to match nested YAML structure
    # Note: Don't use neededForUsers - that puts secrets in /run/secrets-for-users/ instead of /run/secrets/
    # Owner must be the user running the systemd user service, not root
    sops.secrets = {
      "bitwarden/server" = {
        sopsFile = "${sopsFolder}/shared.yaml";
        owner = config.hostSpec.primaryUsername;
        mode = "0400";
      };
      "bitwarden/user_email" = {
        sopsFile = "${sopsFolder}/shared.yaml";
        owner = config.hostSpec.primaryUsername;
        mode = "0400";
      };
      "bitwarden/oauth_client_id" = {
        sopsFile = "${sopsFolder}/shared.yaml";
        owner = config.hostSpec.primaryUsername;
        mode = "0400";
      };
      "bitwarden/oauth_client_secret" = {
        sopsFile = "${sopsFolder}/shared.yaml";
        owner = config.hostSpec.primaryUsername;
        mode = "0400";
      };
    };

    # Consolidated systemd user units
    systemd.user = {
      services = {
        bitwarden-autologin = lib.mkIf cfg.enableAutoLogin {
          description = "Automatically authenticate and unlock Bitwarden using OAuth + libsecret";
          wantedBy = [ "graphical-session.target" ];
          after = [ "graphical-session.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            # Don't restart on failure - secrets may not be available during rebuild
            # User can manually restart if needed
            Restart = "no";
            ExecStart = bitwarden-autologin;
          };
        };

        rbw-sync = {
          description = "Sync rbw vault";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = rbw-sync;
          };
        };
      };

      timers = {
        rbw-sync = {
          description = "Timer for rbw vault sync";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "2min";
            OnUnitActiveSec = "${toString cfg.syncInterval}m";
            Unit = "rbw-sync.service";
          };
        };
      };
    };
  };
}
