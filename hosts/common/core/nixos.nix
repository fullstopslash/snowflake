# Core functionality for every nixos host
{
  config,
  lib,
  pkgs,
  ...
}:
let
  primaryUser = config.hostSpec.primaryUsername;
in
{
  # Create directories needed for home-manager on fresh installs
  # Home-manager looks for profiles in both locations:
  # 1. /nix/var/nix/profiles/per-user/$USER (system-level)
  # 2. ~/.local/state/nix/profiles (user-level, preferred)
  system.activationScripts.nix-profile-dirs = lib.stringAfter [ "users" ] ''
    # System-level profile directory
    mkdir -p /nix/var/nix/profiles/per-user/${primaryUser}
    chown ${primaryUser}:users /nix/var/nix/profiles/per-user/${primaryUser}

    # User-level profile directory (home-manager prefers this)
    home="${config.hostSpec.home}"
    mkdir -p "$home/.local/state/nix/profiles"
    chown -R ${primaryUser}:users "$home/.local"
  '';
  # Add only the terminfo databases we actually need (kitty, ghostty)
  # enableAllTerminfo pulls in broken packages like contour/termbench-pro
  environment.systemPackages = [
    pkgs.kitty.terminfo
    pkgs.ghostty.terminfo
  ];
  # Enable firmware with a license allowing redistribution
  hardware.enableRedistributableFirmware = true;

  # This should be handled by config.security.pam.sshAgentAuth.enable
  security.sudo.extraConfig = ''
    Defaults lecture = never # rollback results in sudo lectures after each reboot, it's somewhat useless anyway
    Defaults pwfeedback # password input feedback - makes typed password visible as asterisks
    Defaults timestamp_timeout=120 # only ask for password every 2h
    # Keep SSH_AUTH_SOCK so that pam_ssh_agent_auth.so can do its magic.
    Defaults env_keep+=SSH_AUTH_SOCK
  '';

  #
  # ========== Nix Helper ==========
  #
  # Provides better build output and will also handle garbage collection in place of standard nix gc (garbage collection)
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 20d --keep 20";
    # Points to where nix-config is located
    # For VMs: /root/nix-config, for regular users: ~/nix-config
    flake = "${config.hostSpec.home}/nix-config";
  };

  #
  # ========== Localization ==========
  #
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  time.timeZone = lib.mkDefault "America/Edmonton";
}
