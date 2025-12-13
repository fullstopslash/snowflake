# Zellij terminal multiplexer
#
# Installs zellij and deploys config from zellij-configs/ directory.
# Config files are plain KDL, not managed in nix.
#
# Usage:
#   myModules.apps.cli.zellij.enable = true;
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.apps.cli.zellij;
  configDir = ./zellij-configs;
  configFile = "${configDir}/config.kdl";
  hasConfig = builtins.pathExists configFile;
in
{
  options.myModules.apps.cli.zellij = {
    enable = lib.mkEnableOption "Zellij terminal multiplexer";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.zellij ];

    # Shell aliases for zellij
    programs.zsh.shellAliases = {
      zl = "zellij";
      zls = "zellij list-sessions";
      zla = "zellij attach";
    };

    # Deploy config via systemd-tmpfiles (runs as each user on login)
    # Creates /etc/skel/.config/zellij/config.kdl for new users
    # Existing users get config via activation script below
    systemd.tmpfiles.rules = lib.optionals hasConfig [
      "d /etc/skel/.config/zellij 0755 root root -"
      "C /etc/skel/.config/zellij/config.kdl 0644 root root - ${configFile}"
    ];

    # For existing users, deploy config on system activation
    system.activationScripts.zellijConfig = lib.optionalString hasConfig ''
      # Deploy zellij config to all non-system users
      for user_home in /home/*; do
        if [ -d "$user_home" ]; then
          user=$(basename "$user_home")
          zellij_dir="$user_home/.config/zellij"

          # Only deploy if user exists and has a home
          if id "$user" &>/dev/null; then
            mkdir -p "$zellij_dir"
            cp "${configFile}" "$zellij_dir/config.kdl"
            chown -R "$user:users" "$zellij_dir"
          fi
        fi
      done
    '';
  };
}
