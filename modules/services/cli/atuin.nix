# Atuin shell history sync service
#
# Provides socket-activated daemon and auto-login service for Atuin.
# Includes sops secrets for credentials - enabled when module is enabled.
#
# The auto-login service:
# - Reads credentials from /run/secrets/atuin/{username,password}
# - Reads encryption key from ~/.local/share/atuin/key (placed by sops)
# - Logs in and performs initial sync on startup/rebuild
#
# Usage:
#   myModules.services.atuin.enable = true;
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.myModules.services.atuin;
  primaryUser = config.hostSpec.primaryUsername;
  sopsFolder = builtins.toString inputs.nix-secrets + "/sops";
in
{
  options.myModules.services.atuin = {
    enable = lib.mkEnableOption "Atuin shell history sync service";
  };

  config = lib.mkIf cfg.enable {
    # Sops secrets for atuin credentials
    sops.secrets = {
      "atuin/username" = {
        sopsFile = "${sopsFolder}/shared.yaml";
        owner = primaryUser;
        mode = "0400";
      };
      "atuin/password" = {
        sopsFile = "${sopsFolder}/shared.yaml";
        owner = primaryUser;
        mode = "0400";
      };
      # Encryption key - stored in user's data dir since atuin reads it from there
      "atuin/key" = {
        sopsFile = "${sopsFolder}/shared.yaml";
        owner = primaryUser;
        path = "/home/${primaryUser}/.local/share/atuin/key";
        mode = "0400";
      };
    };
    # Systemd service to auto-login to Atuin and sync
    # Runs after system activation and on first user login
    systemd.user.services."atuin-autologin" = {
      description = "Atuin auto-login and initial sync";
      wantedBy = [ "default.target" ];
      after = [ "network-online.target" ];
      # Re-run on system activation (rebuilds)
      restartIfChanged = true;
      serviceConfig = {
        Type = "oneshot";
        # Retry on network failures
        Restart = "on-failure";
        RestartSec = 5;
        RestartMaxDelaySec = 30;
      };
      script = ''
        set -eu
        echo "Starting Atuin auto-login..."

        # Ensure directories exist
        mkdir -p "$HOME/.config/atuin" "$HOME/.local/share/atuin"
        ATUIN_BIN="${pkgs.atuin}/bin/atuin"
        KEY_FILE="$HOME/.local/share/atuin/key"
        # Credentials are in /run/secrets (secure tmpfs)
        USERNAME_FILE="/run/secrets/atuin/username"
        PASSWORD_FILE="/run/secrets/atuin/password"
        SESSION_FILE="$HOME/.local/share/atuin/session"

        # Check for required SOPS-provided files
        if [ ! -f "$USERNAME_FILE" ]; then
          echo "Username not found at $USERNAME_FILE (SOPS secret not deployed yet)"
          exit 1  # Exit with error to trigger retry
        fi
        if [ ! -f "$PASSWORD_FILE" ]; then
          echo "Password not found at $PASSWORD_FILE (SOPS secret not deployed yet)"
          exit 1
        fi
        if [ ! -f "$KEY_FILE" ] || [ ! -s "$KEY_FILE" ]; then
          echo "Key not found or empty at $KEY_FILE (SOPS secret not deployed yet)"
          exit 1
        fi

        # Check if already logged in with valid session
        if [ -f "$SESSION_FILE" ]; then
          echo "Session file exists, checking if valid..."
          if "$ATUIN_BIN" status 2>&1 | grep -q "logged in"; then
            echo "Already logged in, syncing..."
            "$ATUIN_BIN" sync || true
            exit 0
          else
            echo "Session invalid, removing and re-logging in..."
            rm -f "$SESSION_FILE"
          fi
        fi

        USERNAME=$(cat "$USERNAME_FILE")
        PASSWORD=$(cat "$PASSWORD_FILE")
        KEY=$(cat "$KEY_FILE")

        echo "Logging in as $USERNAME..."
        # Note: server is configured in ~/.config/atuin/config.toml (sync_address)
        if "$ATUIN_BIN" login -u "$USERNAME" -p "$PASSWORD" -k "$KEY"; then
          echo "Login successful!"
          "$ATUIN_BIN" sync
          echo "Initial sync complete"
        else
          echo "Login failed" 1>&2
          exit 1
        fi
      '';
    };

    # Socket-activated Atuin daemon (default socket: %t/atuin.sock)
    systemd.user.sockets."atuin-daemon" = {
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = "%t/atuin.sock";
        SocketMode = "0600";
      };
    };

    systemd.user.services."atuin-daemon" = {
      description = "Atuin background daemon";
      # Start on socket activation; do not tie to default.target
      wantedBy = [ ];
      after = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.atuin}/bin/atuin daemon";
        Restart = "on-failure";
        RestartSec = 3;
      };
    };
  };
}
