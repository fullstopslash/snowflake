# Universal baseline configuration that ALL roles inherit
# This file contains config that every host gets regardless of role
#
# Hosts get this automatically when ANY role is enabled via roles/default.nix
# Individual roles (desktop, server, etc.) extend this with role-specific config
{
  config,
  inputs,
  outputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.roles;
  # Check if any hardware role is enabled
  anyRoleEnabled =
    cfg.desktop || cfg.laptop || cfg.server || cfg.pi || cfg.tablet || cfg.darwin || cfg.vm;
in
{
  # Universal config that applies when any role is enabled
  config = lib.mkIf anyRoleEnabled {
    #
    # ========== Universal hostSpec defaults ==========
    # These are baseline values - roles and hosts can override with mkDefault/mkForce
    #
    hostSpec = {
      # Identity defaults (hosts typically override hostName)
      primaryUsername = lib.mkDefault "rain";
      username = lib.mkDefault "rain";
      handle = lib.mkDefault "emergentmind";

      # Import secrets from nix-secrets (universal for all hosts)
      inherit (inputs.nix-secrets)
        domain
        email
        userFullName
        networking
        ;

      # Universal behavioral defaults (all production hosts)
      isProduction = lib.mkDefault true;
      hasSecrets = lib.mkDefault true;
      useAtticCache = lib.mkDefault true;

      # Secret categories - base is always enabled, roles add more
      secretCategories = {
        base = lib.mkDefault true;
      };
    };

    #
    # ========== Universal system configuration ==========
    #
    networking.hostName = config.hostSpec.hostName;

    # System-wide packages available even when logged in as root
    environment.systemPackages = [ pkgs.openssh ];

    #
    # ========== Basic shell enablement ==========
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

    # Note: nix.settings is already configured in modules/common/nix.nix

    #
    # ========== Home Manager Configuration ==========
    # Note: Griefling uses home-manager-unstable and imports it directly,
    # so it doesn't use this config. All other hosts use stable home-manager
    # via hosts/common/core/default.nix which already sets useGlobalPkgs and backupFileExtension.
    # This provides extraSpecialArgs for hosts using the role system.
    #
    home-manager.extraSpecialArgs = lib.mkDefault {
      inherit inputs;
      hostSpec = config.hostSpec;
    };
  };
}
