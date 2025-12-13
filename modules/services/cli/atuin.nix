# Atuin shell history sync service
#
# Provides socket-activated daemon, auto-login, and maintenance services for Atuin.
# Includes sops secrets for credentials - enabled when module is enabled.
#
# Services:
# - atuin-autologin: Logs in and syncs on startup/rebuild
# - atuin-maintenance: Daily cleanup tasks (prune, sync, verify)
# - atuin-daemon (user): Socket-activated background daemon
#
# Shell integration:
# - Adds `eval "$(atuin init zsh)"` to /etc/zshrc for all interactive shells
# - Works even when home-manager's zsh is disabled (e.g., chezmoi-managed dotfiles)
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
  cfg = config.myModules.services.cli.atuin;
  primaryUser = config.hostSpec.primaryUsername;
  sopsFolder = builtins.toString inputs.nix-secrets + "/sops";
in
{
  options.myModules.services.cli.atuin = {
    enable = lib.mkEnableOption "Atuin shell history sync service";
  };

  config = lib.mkIf cfg.enable {
    # Add atuin to system packages so users can run it from PATH
    environment.systemPackages = [ pkgs.atuin ];

    # Ensure atuin directories exist with correct ownership before sops-nix creates the key symlink
    # Without this, sops-nix creates the directory as root and the service can't write to it
    systemd.tmpfiles.rules = [
      "d /home/${primaryUser}/.local 0755 ${primaryUser} users -"
      "d /home/${primaryUser}/.local/share 0755 ${primaryUser} users -"
      "d /home/${primaryUser}/.local/share/atuin 0755 ${primaryUser} users -"
      "d /home/${primaryUser}/.config 0755 ${primaryUser} users -"
      "d /home/${primaryUser}/.config/atuin 0755 ${primaryUser} users -"
    ];

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
      # Sync server address - used by autologin service
      "atuin/sync_address" = {
        sopsFile = "${sopsFolder}/shared.yaml";
        owner = primaryUser;
        mode = "0400";
      };
    };

    # System-level shell integration for zsh
    # Uses shellInit (not interactiveShellInit) so it runs for ALL shells including SSH commands
    # This adds to /etc/zshrc, works even when HM's zsh is disabled (chezmoi users)
    programs.zsh.shellInit = ''
      eval "$(${pkgs.atuin}/bin/atuin init zsh)"
    '';

    # System service to auto-login to Atuin and sync
    # Runs at boot, on rebuilds, and periodically via timer for self-healing
    systemd.services."atuin-autologin" = {
      description = "Atuin auto-login and initial sync";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "sops-nix.service"
        "systemd-tmpfiles-setup.service"
      ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = primaryUser;
        Group = "users";
        RemainAfterExit = true;
      };
      script = ''
        set -eu
        echo "Starting Atuin auto-login..."

        HOME="/home/${primaryUser}"
        export HOME

        # Ensure directories exist
        mkdir -p "$HOME/.config/atuin" "$HOME/.local/share/atuin"
        ATUIN_BIN="${pkgs.atuin}/bin/atuin"
        KEY_FILE="$HOME/.local/share/atuin/key"
        CONFIG_FILE="$HOME/.config/atuin/config.toml"
        # Credentials are in /run/secrets (secure tmpfs)
        USERNAME_FILE="/run/secrets/atuin/username"
        PASSWORD_FILE="/run/secrets/atuin/password"
        SYNC_ADDRESS_FILE="/run/secrets/atuin/sync_address"
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
        if [ ! -f "$SYNC_ADDRESS_FILE" ]; then
          echo "Sync address not found at $SYNC_ADDRESS_FILE (SOPS secret not deployed yet)"
          exit 1
        fi

        # Ensure sync_address is set in config.toml
        SYNC_ADDRESS=$(cat "$SYNC_ADDRESS_FILE")
        if [ -f "$CONFIG_FILE" ]; then
          # Update existing config if sync_address is different
          if grep -q "^sync_address" "$CONFIG_FILE"; then
            ${pkgs.gnused}/bin/sed -i "s|^sync_address.*|sync_address = \"$SYNC_ADDRESS\"|" "$CONFIG_FILE"
          else
            # Add sync_address after the commented line or at the top
            if grep -q "# sync_address" "$CONFIG_FILE"; then
              ${pkgs.gnused}/bin/sed -i "/# sync_address/a sync_address = \"$SYNC_ADDRESS\"" "$CONFIG_FILE"
            else
              echo "sync_address = \"$SYNC_ADDRESS\"" >> "$CONFIG_FILE"
            fi
          fi
        else
          # Create minimal config with sync_address
          echo "sync_address = \"$SYNC_ADDRESS\"" > "$CONFIG_FILE"
        fi
        echo "Configured sync_address: $SYNC_ADDRESS"

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

    # Daily maintenance service - prune, sync, verify
    systemd.services."atuin-maintenance" = {
      description = "Atuin daily maintenance (prune, sync, verify)";
      after = [
        "network-online.target"
        "atuin-autologin.service"
      ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = primaryUser;
        Group = "users";
      };
      script = ''
        set -eu
        echo "Starting Atuin maintenance..."

        HOME="/home/${primaryUser}"
        export HOME
        ATUIN_BIN="${pkgs.atuin}/bin/atuin"
        SESSION_FILE="$HOME/.local/share/atuin/session"

        # Only run if logged in
        if [ ! -f "$SESSION_FILE" ]; then
          echo "Not logged in, skipping maintenance"
          exit 0
        fi

        # Prune history matching exclusion filters
        echo "Pruning history..."
        "$ATUIN_BIN" history prune || echo "Prune failed (may have no exclusion filters configured)"

        # Sync after prune
        echo "Syncing..."
        "$ATUIN_BIN" sync || echo "Sync failed"

        # Verify store integrity
        echo "Verifying store..."
        if "$ATUIN_BIN" store verify; then
          echo "Store verification OK"
        else
          echo "Store verification failed - may need attention" >&2
        fi

        echo "Maintenance complete"
      '';
    };

    # Timer for daily maintenance
    systemd.timers."atuin-maintenance" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily"; # Run once per day
        Persistent = true; # Run immediately if missed (e.g., machine was off)
        RandomizedDelaySec = "1h"; # Spread load across machines
        Unit = "atuin-maintenance.service";
      };
    };

    # Socket-activated Atuin daemon
    # Note: socket path must match config.toml's daemon.socket_path (chezmoi dotfiles)
    systemd.user.sockets."atuin-daemon" = {
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = "%t/atuin.socket";
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
