# CLI secrets category: credentials for CLI tools
#
# Includes secrets for Atuin shell history sync and other CLI applications.

{
  lib,
  inputs,
  config,
  pkgs,
  ...
}:
let
  sopsFolder = builtins.toString inputs.nix-secrets + "/sops";
  hasSecrets = config.hostSpec.hasSecrets;
  cliEnabled = config.hostSpec.secretCategories.cli or false;
in
{
  config = lib.mkIf (hasSecrets && cliEnabled) {
    sops.secrets = {
      # Atuin credentials for shell history sync
      # Secret names map to nested YAML paths atuin/username, atuin/password, atuin/key
      "atuin/username" = {
        sopsFile = "${sopsFolder}/shared.yaml";
        owner = config.hostSpec.primaryUsername;
        path = "/home/${config.hostSpec.primaryUsername}/.config/atuin/.username";
        mode = "0600";
      };
      "atuin/password" = {
        sopsFile = "${sopsFolder}/shared.yaml";
        owner = config.hostSpec.primaryUsername;
        path = "/home/${config.hostSpec.primaryUsername}/.config/atuin/.password";
        mode = "0600";
      };
      # Encryption key for syncing - must be the same across all devices
      "atuin/key" = {
        sopsFile = "${sopsFolder}/shared.yaml";
        owner = config.hostSpec.primaryUsername;
        path = "/home/${config.hostSpec.primaryUsername}/.local/share/atuin/key";
        mode = "0600";
      };
    };

    # Systemd service to auto-login to Atuin
    systemd.user.services."atuin-autologin" = {
      description = "Atuin auto-login and initial sync";
      wantedBy = [ "default.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
        set -eu
        echo "Starting Atuin auto-login..."

        # Ensure directories exist (SOPS creates the key file via path)
        mkdir -p "$HOME/.config/atuin" "$HOME/.local/share/atuin"
        ATUIN_BIN="${pkgs.atuin}/bin/atuin"
        KEY_FILE="$HOME/.local/share/atuin/key"
        USERNAME_FILE="$HOME/.config/atuin/.username"
        PASSWORD_FILE="$HOME/.config/atuin/.password"
        SESSION_FILE="$HOME/.local/share/atuin/session"

        # Check for required SOPS-provided files
        if [ ! -f "$USERNAME_FILE" ]; then
          echo "Username file not found at $USERNAME_FILE (SOPS secret not deployed yet), skipping..."
          exit 0
        fi
        if [ ! -f "$PASSWORD_FILE" ]; then
          echo "Password file not found at $PASSWORD_FILE (SOPS secret not deployed yet), skipping..."
          exit 0
        fi
        if [ ! -f "$KEY_FILE" ] || [ ! -s "$KEY_FILE" ]; then
          echo "Key file not found or empty at $KEY_FILE (SOPS secret not deployed yet), skipping..."
          exit 0
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
          "$ATUIN_BIN" sync || true
        else
          echo "Login failed" 1>&2
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
