# Laptop role - portable desktop with power management
#
# Extends desktop with: power management, wifi, bluetooth, touchpad
# Uses unified module selection - hosts can override individual categories
# Secret categories: base, desktop, network
{ config, lib, ... }:
{
  config = lib.mkIf (builtins.elem "laptop" config.roles) {
    # ========================================
    # MODULE SELECTIONS (same as desktop)
    # ========================================
    # Paths mirror filesystem: modules/<top>/<category> = [ "<module>" ]
    modules = {
      apps = {
        media = [ "media" ];
        gaming = [ "gaming" ];
        comms = [ "comms" ];
        productivity = [ "productivity" ];
        cli = [
          "comma"
          "shell"
          "tools-core"
        ];
        development = [
          "latex"
          "document-processing"
        ];
      };
      services = {
        desktop = [
          "plasma"
          "hyprland"
          "wayland"
          "common"
        ];
        display-manager = [ "ly" ];
        development = [ "containers" ];
        cli = [ "atuin" ];
        networking = [ "ssh" ];
        audio = [ "pipewire" ];
      };
    };

    # ========================================
    # SYSTEM DEFAULTS
    # ========================================
    services.xserver.enable = lib.mkDefault true;
    hardware.graphics.enable = lib.mkDefault true;

    # Laptop-specific: Power management
    services.thermald.enable = lib.mkDefault true;
    services.power-profiles-daemon.enable = lib.mkDefault true;
    powerManagement.enable = lib.mkDefault true;

    # Laptop-specific: Wifi
    networking.wireless.enable = lib.mkDefault false; # Use networkmanager
    networking.networkmanager.wifi.powersave = lib.mkDefault true;

    # Laptop-specific: Hardware
    services.libinput.enable = lib.mkDefault true;
    hardware.bluetooth.enable = lib.mkDefault true;

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
    host = {
      # Architecture (laptops are typically x86_64)
      architecture = lib.mkDefault "x86_64-linux";

      wifi = lib.mkDefault true;
      isMobile = lib.mkDefault true;

      secretCategories = {
        base = lib.mkDefault true;
        desktop = lib.mkDefault true;
        network = lib.mkDefault true;
        cli = lib.mkDefault true;
      };
    };
  };
}
