# Server role - headless production server
#
# Enables: SSH, firewall, CLI tools, auto-upgrade
# Uses unified module selection - headless by default
# Secret categories: base, server, network
{ config, lib, ... }:
{
  config = lib.mkIf (builtins.elem "server" config.roles) {
    # ========================================
    # MODULE SELECTIONS (headless)
    # ========================================
    # Paths mirror filesystem: modules/<top>/<category> = [ "<module>" ]
    modules = {
      apps = {
        cli = [
          "comma"
          "shell"
          "tools-core"
        ];
      };
      services = {
        cli = [ "atuin" ];
        networking = [
          "ssh"
          "openssh"
        ];
      };
    };

    # ========================================
    # SYSTEM DEFAULTS
    # ========================================
    networking.firewall.enable = lib.mkDefault true;
    services.xserver.enable = lib.mkDefault false;

    # ========================================
    # GOLDEN GENERATION (boot safety)
    # ========================================
    myModules.system.boot.goldenGeneration = {
      enable = lib.mkDefault true;
      validateServices = lib.mkDefault [
        "sshd.service"
        "tailscaled.service"
      ];
      autoPinAfterBoot = lib.mkDefault true;
    };

    # ========================================
    # CHEZMOI DOTFILE SYNC
    # ========================================
    myModules.services.dotfiles.chezmoiSync = {
      enable = lib.mkDefault false; # Disabled by default, hosts must opt-in with repoUrl
      # repoUrl must be set by host (e.g., "git@github.com:user/dotfiles.git")
      syncBeforeUpdate = lib.mkDefault true;
      autoCommit = lib.mkDefault true;
      autoPush = lib.mkDefault true;
    };

    # ========================================
    # HOSTSPEC (non-derived options only)
    # ========================================
    hostSpec = {
      # Architecture (servers are typically x86_64)
      architecture = lib.mkDefault "x86_64-linux";

      isProduction = lib.mkDefault true;
      wifi = lib.mkDefault false;

      secretCategories = {
        base = lib.mkDefault true;
        server = lib.mkDefault true;
        network = lib.mkDefault true;
        cli = lib.mkDefault true;
      };
    };
  };
}
