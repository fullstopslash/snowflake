# Universal settings for ALL hosts (NixOS, Darwin, VMs, ISOs)
#
# This is the single source of truth for universal configuration.
# All hosts inherit these settings regardless of platform or role.
#
# Contains:
# - host identity defaults
# - System-wide packages
# - Shell configuration (zsh)
# - Nixpkgs overlays
# - Localization
# - NixOS-specific defaults (terminfo, firmware) - conditional on Linux
#
# Note: Home-manager settings are in roles/common.nix (where the module is imported)
# Note: Nix settings are in nix-management.nix, SOPS settings are in sops.nix
{
  inputs,
  outputs,
  config,
  lib,
  pkgs,
  ...
}:
{
  #
  # ========== Identity Defaults ==========
  # Hosts can override these with lib.mkForce
  #
  identity = {
    primaryUsername = lib.mkDefault "rain";
    handle = lib.mkDefault "fullstopslash";

    # Import secrets from nix-secrets (universal for all hosts)
    inherit (inputs.nix-secrets)
      domain
      email
      userFullName
      networking
      ;
  };

  #
  # ========== System-wide Packages ==========
  # Available even when logged in as root
  #
  environment.systemPackages = [
    pkgs.openssh
    pkgs.just # Justfile task runner
    pkgs.rsync # File synchronization
  ]
  ++ lib.optionals pkgs.stdenv.isLinux [
    # Terminal emulator terminfo (NixOS only, skip on headless)
    pkgs.kitty.terminfo
    pkgs.ghostty.terminfo
  ];

  #
  # ========== Shell and Version Control ==========
  # On darwin it's important this is outside home-manager
  #
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    promptInit = "source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
  };
  programs.git.enable = true;

  #
  # ========== Overlays ==========
  #
  nixpkgs.overlays = lib.mkDefault [ outputs.overlays.default ];

  #
  # ========== Localization ==========
  #
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  time.timeZone = lib.mkDefault "America/Chicago";

  #
  # ========== NixOS-Specific Defaults ==========
  # Only applies to Linux/NixOS hosts, not Darwin
  #

  # Enable firmware with a license allowing redistribution
  hardware.enableRedistributableFirmware = lib.mkIf pkgs.stdenv.isLinux true;

  # Home-manager profile directories (needed for fresh installs)
  # Home-manager looks for profiles in both locations:
  # 1. /nix/var/nix/profiles/per-user/$USER (system-level)
  # 2. ~/.local/state/nix/profiles (user-level, preferred)
  system.activationScripts.nix-profile-dirs = lib.mkIf pkgs.stdenv.isLinux (
    lib.stringAfter [ "users" ] ''
      # System-level profile directory
      mkdir -p /nix/var/nix/profiles/per-user/${config.identity.primaryUsername}
      chown ${config.identity.primaryUsername}:users /nix/var/nix/profiles/per-user/${config.identity.primaryUsername}

      # User-level profile directory (home-manager prefers this)
      home="${config.identity.home}"
      mkdir -p "$home/.local/state/nix/profiles"
      chown -R ${config.identity.primaryUsername}:users "$home/.local"
    ''
  );

  # Sudo configuration (NixOS only)
  security.sudo.extraConfig = lib.mkIf pkgs.stdenv.isLinux ''
    Defaults lecture = never # rollback results in sudo lectures after each reboot, it's somewhat useless anyway
    Defaults pwfeedback # password input feedback - makes typed password visible as asterisks
    Defaults timestamp_timeout=120 # only ask for password every 2h
    # Keep SSH_AUTH_SOCK so that pam_ssh_agent_auth.so can do its magic.
    Defaults env_keep+=SSH_AUTH_SOCK
  '';
}
