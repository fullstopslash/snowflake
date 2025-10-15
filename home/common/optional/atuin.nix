#Note: ctrl+r to cycle filter modes
{
  inputs,
  config,
  ...
}:
let
  sopsFolder = (builtins.toString inputs.nix-secrets) + "/sops";
in
{
  programs.atuin = {
    enable = true;
    
    # Enable daemon for background syncing
    daemon.enable = true;

    enableBashIntegration = false;
    enableZshIntegration = true;
    enableFishIntegration = false;

    settings = {
      auto_sync = true;
      #FIXME(atuin): move to private server
      sync_address = "http://waterbug.lan:3333";
      sync_frequency = "5m";
      update_check = false;
      filter_mode = "global";
      invert = true;
      enter_accept = true;
      #TODO(atuin): disable when comfortable
      show_help = true;
      prefers_reduced_motion = true;

      style = "compact";
      inline_height = 10;
      search_mode = "fuzzy";
      filter_mode_shell_up_key_binding = "session";

      # This came from https://github.com/nifoc/dotfiles/blob/ce5f9e935db1524d008f97e04c50cfdb41317766/home/programs/atuin.nix#L2
      history_filter = [
        "^base64decode"
        "^instagram-dl"
        "^mp4concat"
      ];
    };

    # We use down to trigger, and use up to quickly edit the last entry only
    flags = [ "--disable-up-arrow" ];
  };
  sops.secrets."keys/age/atuin" = {
    path = "${config.home.homeDirectory}/.local/share/atuin/key";
    sopsFile = "${sopsFolder}/shared.yaml";
  };
  
  sops.secrets."atuin/username" = {
    path = "${config.home.homeDirectory}/.config/atuin/.username";
    sopsFile = "${sopsFolder}/shared.yaml";
  };
  
  sops.secrets."atuin/password" = {
    path = "${config.home.homeDirectory}/.config/atuin/.password";
    sopsFile = "${sopsFolder}/shared.yaml";
  };

  # Auto-login to atuin if key exists but session doesn't, then sync immediately
  home.activation.atuinLogin = config.lib.dag.entryAfter [ "reloadSystemd" ] ''
    KEY_FILE="$HOME/.local/share/atuin/key"
    USERNAME_FILE="$HOME/.config/atuin/.username"
    PASSWORD_FILE="$HOME/.config/atuin/.password"
    SESSION_FILE="$HOME/.local/share/atuin/session"
    
    if [ -f "$KEY_FILE" ] && [ -f "$USERNAME_FILE" ] && [ -f "$PASSWORD_FILE" ] && [ ! -f "$SESSION_FILE" ]; then
      USERNAME=$(cat "$USERNAME_FILE")
      PASSWORD=$(cat "$PASSWORD_FILE")
      echo "🔐 Logging into atuin as $USERNAME..."
      # Find atuin in PATH or nix profile
      ATUIN_BIN=$(PATH="$HOME/.nix-profile/bin:$PATH" command -v atuin 2>/dev/null || true)
      if [ -n "$ATUIN_BIN" ]; then
        if $DRY_RUN_CMD "$ATUIN_BIN" login -u "$USERNAME" -p "$PASSWORD" -k "$(cat "$KEY_FILE")"; then
          echo "✅ Atuin login successful"
          echo "🔄 Syncing history immediately..."
          $DRY_RUN_CMD "$ATUIN_BIN" sync && echo "✅ Initial sync complete" || echo "⚠️  Initial sync failed"
        else
          echo "⚠️  Atuin login failed"
        fi
      else
        echo "⚠️  Atuin binary not found in PATH"
      fi
    fi
  '';

  programs.zsh.initContent = ''
    # Bind down key for atuin, specifically because we use invert
    bindkey "$key[Down]"  atuin-up-search
  '';

}
