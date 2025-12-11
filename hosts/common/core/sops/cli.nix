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
      # Secret names map to nested YAML paths atuin/username and atuin/password
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

        mkdir -p "$HOME/.config/atuin" "$HOME/.local/share/atuin"
        ATUIN_BIN="${pkgs.atuin}/bin/atuin"
        KEY_FILE="$HOME/.local/share/atuin/key"
        USERNAME_FILE="$HOME/.config/atuin/.username"
        PASSWORD_FILE="$HOME/.config/atuin/.password"
        SESSION_FILE="$HOME/.local/share/atuin/session"

        # Generate a key if missing
        if [ ! -f "$KEY_FILE" ]; then
          echo "Generating new Atuin key..."
          "$ATUIN_BIN" gen-key > "$KEY_FILE" 2>&1 || true
          if [ -s "$KEY_FILE" ]; then
            chmod 600 "$KEY_FILE"
            echo "Key generated successfully"
          else
            echo "Failed to generate key, trying alternative method..."
            # Alternative: use key generate command
            "$ATUIN_BIN" key generate 2>&1 | head -1 > "$KEY_FILE" || true
            chmod 600 "$KEY_FILE" 2>/dev/null || true
          fi
        fi

        # Check if already logged in
        if [ -f "$SESSION_FILE" ]; then
          echo "Session file exists, checking if valid..."
          if "$ATUIN_BIN" status 2>&1 | grep -q "logged in"; then
            echo "Already logged in, skipping login"
            "$ATUIN_BIN" sync || true
            exit 0
          else
            echo "Session invalid, removing and re-logging in..."
            rm -f "$SESSION_FILE"
          fi
        fi

        # Check for required files
        if [ ! -f "$USERNAME_FILE" ]; then
          echo "Username file not found at $USERNAME_FILE, skipping..."
          exit 0
        fi
        if [ ! -f "$PASSWORD_FILE" ]; then
          echo "Password file not found at $PASSWORD_FILE, skipping..."
          exit 0
        fi
        if [ ! -f "$KEY_FILE" ] || [ ! -s "$KEY_FILE" ]; then
          echo "Key file not found or empty at $KEY_FILE, skipping..."
          exit 0
        fi

        USERNAME=$(cat "$USERNAME_FILE")
        PASSWORD=$(cat "$PASSWORD_FILE")
        KEY=$(cat "$KEY_FILE")

        echo "Logging in as $USERNAME to LAN server..."
        if "$ATUIN_BIN" login \
            --server "http://waterbug.lan:3333" \
            -u "$USERNAME" -p "$PASSWORD" -k "$KEY"; then
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
