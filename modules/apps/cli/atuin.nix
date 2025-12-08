{
  pkgs,
  ...
}:
{
  # Provide Atuin credentials via SOPS (paths match this repo's secrets.yaml)
  sops.secrets."atuin/username" = {
    # Write into the user's config directory
    path = "/home/rain/.config/atuin/.username";
    owner = "rain";
    group = "rain";
    mode = "0600";
  };

  sops.secrets."atuin/password" = {
    path = "/home/rain/.config/atuin/.password";
    owner = "rain";
    group = "rain";
    mode = "0600";
  };

  # User service to ensure login and initial sync
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
      KEY_FILE="$HOME/.local/share/atuin/key"
      USERNAME_FILE="$HOME/.config/atuin/.username"
      PASSWORD_FILE="$HOME/.config/atuin/.password"
      SESSION_FILE="$HOME/.local/share/atuin/session"

      # Generate a key if missing
      if [ ! -f "$KEY_FILE" ]; then
        if "$ATUIN_BIN" key generate > "$KEY_FILE" 2>/dev/null; then
          chmod 600 "$KEY_FILE"
        fi
      fi

      if [ -f "$KEY_FILE" ] && [ -f "$USERNAME_FILE" ] && [ -f "$PASSWORD_FILE" ] && [ ! -f "$SESSION_FILE" ]; then
        USERNAME=$(cat "$USERNAME_FILE")
        PASSWORD=$(cat "$PASSWORD_FILE")
        # Use the LAN server; keep in sync with your infra
        "$ATUIN_BIN" login \
          --server "http://waterbug.lan:3333" \
          -u "$USERNAME" -p "$PASSWORD" -k "$(cat "$KEY_FILE")" || true
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

  # zsh integration without Home Manager
  programs.zsh.interactiveShellInit = ''
    # Initialize Atuin for zsh and disable stealing the Up arrow
    if command -v atuin >/dev/null 2>&1; then
      eval "$(atuin init zsh --disable-up-arrow)"
      # Bind Down arrow to trigger search (works well with invert)
      bindkey "$key[Down]" atuin-up-search
    fi
  '';
}
