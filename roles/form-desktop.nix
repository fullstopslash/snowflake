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
    # Hosts can override with: modules.services.desktop = lib.mkForce [ "niri" ];
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
          "tools"
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

    # ========================================
    # HOSTSPEC (non-derived options only)
    # ========================================
    # Note: useWayland, isDevelopment, isMinimal, useWindowManager are now
    # derived from modules.* selections in host-spec.nix
    hostSpec = {
      # Hardware default (desktops typically use ethernet)
      wifi = lib.mkDefault false;
      # Form factor
      isMobile = lib.mkDefault false;

      # Secret categories
      secretCategories = {
        base = lib.mkDefault true;
        desktop = lib.mkDefault true;
        network = lib.mkDefault true;
        cli = lib.mkDefault true;
      };
    };
  };
}
