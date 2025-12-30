# Desktop role - full graphical workstation
#
# Enables: GUI desktop environment, audio, media apps, gaming, development tools
# Uses unified module selection - hosts can override individual categories
# Secret categories: base, desktop, network
{ config, lib, ... }:
{
  config = lib.mkIf (builtins.elem "desktop" config.roles) {
    # ========================================
    # MODULE SELECTIONS
    # ========================================
    # Hosts can override with: modules.apps.window-managers = lib.mkForce [ "niri" ];
    # Paths mirror filesystem: modules/<top>/<category> = [ "<module>" ]

    modules = {
      apps = {
        window-managers = [
          "hyprland"
          "plasma"
        ];
        desktop = [
          "desktop"
          "rofi"
          "waybar"
          "dunst"
          "wayland"
        ];
        browsers = [
          "firefox"
          # "brave"     # Optional: enable if desired
          # "chromium"  # Optional: enable if desired
        ];
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
        desktop = [ "common" ];
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
    # SYSTEM CONFIGURATION
    # ========================================
    # Architecture and nixpkgs variant
    system = {
      architecture = lib.mkDefault "x86_64-linux";
      nixpkgsVariant = lib.mkDefault "stable";
      isDarwin = lib.mkDefault false;
    };

    # Hardware defaults (desktops typically use ethernet)
    hardware.host.wifi = lib.mkDefault false;

    # Secret categories
    sops.categories = {
      base = lib.mkDefault true;
      desktop = lib.mkDefault true;
      network = lib.mkDefault true;
      cli = lib.mkDefault true;
    };
  };
}
