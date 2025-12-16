# NixOS-specific user defaults
#
# User-related settings that only apply to NixOS hosts (not Darwin).
# These are settings that support user account functionality.
#
# Contains:
# - Home-manager profile directory setup
# - Sudo configuration
{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf pkgs.stdenv.isLinux {
  #
  # ========== Home-manager Profile Directories ==========
  #
  # Create directories needed for home-manager on fresh installs
  # Home-manager looks for profiles in both locations:
  # 1. /nix/var/nix/profiles/per-user/$USER (system-level)
  # 2. ~/.local/state/nix/profiles (user-level, preferred)
  system.activationScripts.nix-profile-dirs =
    let
      primaryUser = config.host.primaryUsername;
    in
    lib.stringAfter [ "users" ] ''
      # System-level profile directory
      mkdir -p /nix/var/nix/profiles/per-user/${primaryUser}
      chown ${primaryUser}:users /nix/var/nix/profiles/per-user/${primaryUser}

      # User-level profile directory (home-manager prefers this)
      home="${config.host.home}"
      mkdir -p "$home/.local/state/nix/profiles"
      chown -R ${primaryUser}:users "$home/.local"
    '';

  #
  # ========== Sudo Configuration ==========
  #
  security.sudo.extraConfig = ''
    Defaults lecture = never # rollback results in sudo lectures after each reboot, it's somewhat useless anyway
    Defaults pwfeedback # password input feedback - makes typed password visible as asterisks
    Defaults timestamp_timeout=120 # only ask for password every 2h
    # Keep SSH_AUTH_SOCK so that pam_ssh_agent_auth.so can do its magic.
    Defaults env_keep+=SSH_AUTH_SOCK
  '';
}
