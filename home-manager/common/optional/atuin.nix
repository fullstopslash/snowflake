#Note: ctrl+r to cycle filter modes
# Atuin configuration is minimal here - secrets and systemd services are handled
# at the NixOS level via hosts/common/core/sops/cli.nix
{ lib, ... }:
{
  # Force overwrite atuin config to avoid conflicts on fresh installs
  # The config.toml might be created by sops-nix activation before home-manager runs
  # mkForce needed to override the default `force = false` from programs.atuin module
  xdg.configFile."atuin/config.toml".force = lib.mkForce true;

  programs.atuin = {
    enable = true;

    # Daemon is managed by systemd at NixOS level (see sops/cli.nix)
    daemon.enable = false;

    enableBashIntegration = false;
    enableZshIntegration = true;
    enableFishIntegration = false;

    settings = {
      auto_sync = true;
      sync_address = "http://waterbug.lan:3333";
      sync_frequency = "5m";
      update_check = false;
      filter_mode = "global";
      invert = true;
      enter_accept = true;
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

  programs.zsh.initExtra = ''
    # Bind down key for atuin, specifically because we use invert
    bindkey "$key[Down]"  atuin-up-search
  '';
}
