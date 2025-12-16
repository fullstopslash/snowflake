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
#
# Note: Home-manager settings are in roles/common.nix (where the module is imported)
# Note: Nix settings are in nix.nix, SOPS settings are in sops.nix
# Note: NixOS-specific settings are in nixos-defaults.nix
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
  host = {
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
  # ========== Networking ==========
  #
  networking.hostName = config.host.hostName;

  #
  # ========== System-wide Packages ==========
  # Available even when logged in as root
  #
  environment.systemPackages = [ pkgs.openssh ];

  #
  # ========== Shell Configuration ==========
  # On darwin it's important this is outside home-manager
  #
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    promptInit = "source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
  };

  #
  # ========== Overlays ==========
  #
  nixpkgs.overlays = lib.mkDefault [ outputs.overlays.default ];

  #
  # ========== Localization ==========
  #
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  time.timeZone = lib.mkDefault "America/Chicago";
}
