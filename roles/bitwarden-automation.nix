# Bitwarden automation role
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.roles.bitwardenAutomation;

  # Create a script that uses OAuth + KDE Wallet for full automation
  bitwarden-autologin = pkgs.writeShellScript "bitwarden-autologin" ''
    #!/usr/bin/env sh
    set -eu

    echo "Starting Bitwarden OAuth + KDE Wallet automation..."

    # Read secrets from SOPS
    BW_SERVER=$(cat ${config.sops.secrets."bitwarden-server".path})
    BW_USEREMAIL=$(cat ${config.sops.secrets."bitwarden-user-email".path})
    BITWARDEN_OAUTH_CLIENT_ID=$(cat ${config.sops.secrets."bitwarden-oauth-client-id".path})
    BITWARDEN_OAUTH_CLIENT_SECRET=$(cat ${config.sops.secrets."bitwarden-oauth-client-secret".path})

    if [ -z "$BW_SERVER" ] || [ -z "$BW_USEREMAIL" ] || [ -z "$BITWARDEN_OAUTH_CLIENT_ID" ] || [ -z "$BITWARDEN_OAUTH_CLIENT_SECRET" ]; then
      echo "Missing Bitwarden credentials from SOPS secrets" 1>&2
      exit 1
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

    # If we're locked, try to unlock using KDE Wallet
    if [ "$STATUS" = "locked" ]; then
      echo "Attempting to unlock using KDE Wallet..."

      # Try to get password from KDE Wallet
      STORED_PASSWORD=$(${pkgs.kdePackages.kwallet}/bin/kwallet-query -f bitwarden -e bitwarden-master-password 2>/dev/null || echo "")

      if [ -n "$STORED_PASSWORD" ]; then
        echo "Found stored password in KDE Wallet, attempting unlock..."
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

      # If still locked, prompt user and store in KDE Wallet
      if [ "$STATUS" = "locked" ]; then
        echo "No stored password or stored password failed."
        echo "Please unlock manually with: bw unlock"
        echo "After unlocking, run this script again to store the password in KDE Wallet."
        echo ""
        echo "To store password for future use, run:"
        echo "echo 'your-master-password' | ${pkgs.kdePackages.kwallet}/bin/kwallet-query -f bitwarden -w bitwarden-master-password"
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
in {
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
      kdePackages.kwallet
    ];

    # SOPS secrets for Bitwarden automation
    sops.secrets = {
      bitwarden-server = {
        key = "bitwarden_server";
        owner = "root";
        neededForUsers = true;
      };
      bitwarden-user-email = {
        key = "bitwarden_user_email";
        owner = "root";
        neededForUsers = true;
      };
      bitwarden-oauth-client-id = {
        key = "bitwarden_oauth_client_id";
        owner = "root";
        neededForUsers = true;
      };
      bitwarden-oauth-client-secret = {
        key = "bitwarden_oauth_client_secret";
        owner = "root";
        neededForUsers = true;
      };
    };

    # Consolidated systemd user units
    systemd.user = {
      services = {
        bitwarden-autologin = lib.mkIf cfg.enableAutoLogin {
          description = "Automatically authenticate and unlock Bitwarden using OAuth + KDE Wallet";
          wantedBy = ["graphical-session.target"];
          after = ["graphical-session.target"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            Restart = "on-failure";
            RestartSec = 30;
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
          wantedBy = ["timers.target"];
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
