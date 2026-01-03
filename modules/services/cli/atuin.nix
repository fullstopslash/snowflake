# Atuin shell history sync service
#
# Compatible with Atuin 18.10.0+
#
# Provides socket-activated daemon, auto-login, and shell integration for Atuin.
# Uses Atuin 18.10+ auto-generated encryption keys (simpler than managing keys via SOPS).
#
# Services:
# - atuin-autologin (user): Logs in and syncs on user session start
# - atuin-daemon (user): Socket-activated background daemon
#
# Shell integration:
# - Adds `eval "$(atuin init zsh --disable-up-arrow)"` to zsh
# - Binds Down arrow to trigger search
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
  primaryUser = config.identity.primaryUsername;
  sopsFolder = builtins.toString inputs.nix-secrets + "/sops";
in
{
  config = {
    # Add atuin to system packages
    environment.systemPackages = [ pkgs.atuin ];

    # Ensure atuin directories exist with correct ownership
    systemd.tmpfiles.rules = [
      "d /home/${primaryUser}/.local 0755 ${primaryUser} users -"
      "d /home/${primaryUser}/.local/share 0755 ${primaryUser} users -"
      "d /home/${primaryUser}/.local/share/atuin 0755 ${primaryUser} users -"
      "d /home/${primaryUser}/.config 0755 ${primaryUser} users -"
      "d /home/${primaryUser}/.config/atuin 0755 ${primaryUser} users -"
    ];

    # Sops secrets for atuin credentials - write to user config directory
    sops.secrets."atuin/username" = {
      sopsFile = "${sopsFolder}/shared.yaml";
      path = "/home/${primaryUser}/.config/atuin/.username";
      owner = primaryUser;
      group = "users";
      mode = "0600";
    };

    sops.secrets."atuin/password" = {
      sopsFile = "${sopsFolder}/shared.yaml";
      path = "/home/${primaryUser}/.config/atuin/.password";
      owner = primaryUser;
      group = "users";
      mode = "0600";
    };

    # Shell integration for zsh (Atuin 18.10.0+ compatible)
    programs.zsh.interactiveShellInit = ''
      # Initialize Atuin for zsh and disable stealing the Up arrow
      if command -v atuin >/dev/null 2>&1; then
        eval "$(atuin init zsh --disable-up-arrow)"
        # Bind Down arrow to trigger search (works well with invert)
        bindkey "$key[Down]" atuin-up-search
      fi
    '';

    # User service to auto-login to Atuin and sync
    # Runs when user session starts
    systemd.user.services."atuin-autologin" = {
      description = "Atuin auto-login and initial sync";
      wantedBy = [ "default.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
        mkdir -p "$HOME/.config/atuin" "$HOME/.local/share/atuin"
        ATUIN_BIN="$(command -v atuin)" || exit 0
        USERNAME_FILE="$HOME/.config/atuin/.username"
        PASSWORD_FILE="$HOME/.config/atuin/.password"
        SESSION_FILE="$HOME/.local/share/atuin/session"

        # If not logged in and credentials exist, attempt login
        # In Atuin 18.10+, the encryption key is auto-generated on first login
        # Server is configured in ~/.config/atuin/config.toml
        if [ ! -f "$SESSION_FILE" ] && [ -f "$USERNAME_FILE" ] && [ -f "$PASSWORD_FILE" ]; then
          USERNAME=$(cat "$USERNAME_FILE")
          PASSWORD=$(cat "$PASSWORD_FILE")
          "$ATUIN_BIN" login -u "$USERNAME" -p "$PASSWORD" || true
          "$ATUIN_BIN" sync || true
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
