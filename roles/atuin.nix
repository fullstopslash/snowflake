{
  lib,
  pkgs,
  ...
}: {
  # Provide Atuin credentials via SOPS (paths match nix-secrets shared.yaml)
  sops.secrets."atuin/username" = {
    key = "atuin/username";
    # Write into the user's config directory
    path = "/home/rain/.config/atuin/.username";
    owner = "rain";
    group = "rain";
    mode = "0600";
  };

  sops.secrets."atuin/password" = {
    key = "atuin/password";
    path = "/home/rain/.config/atuin/.password";
    owner = "rain";
    group = "rain";
    mode = "0600";
  };

  # User service to ensure login and initial sync
  systemd.user.services."atuin-autologin" = {
    description = "Atuin auto-login and initial sync";
    wantedBy = ["default.target"];
    after = ["network-online.target"];
    serviceConfig = {Type = "oneshot";};
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
    wantedBy = ["sockets.target"];
    socketConfig = {
      ListenStream = "%t/atuin.sock";
      SocketMode = "0600";
    };
  };

  systemd.user.services."atuin-daemon" = {
    description = "Atuin background daemon";
    # Start on socket activation; do not tie to default.target
    wantedBy = [];
    after = ["network-online.target"];
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
