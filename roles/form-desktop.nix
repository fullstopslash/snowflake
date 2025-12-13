# Desktop role - full graphical workstation
#
# Enables: GUI desktop environment, audio, media apps, gaming, development tools
# Uses unified module selection - hosts can override individual categories
# Secret categories: base, desktop, network
{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  config = lib.mkIf cfg.desktop {
    # ========================================
    # MODULE SELECTIONS
    # ========================================
    # Hosts can override with: modules.desktop = lib.mkForce [ "niri" ];
    # Or extend with: modules.services = config.modules.services ++ [ "extra" ];

    modules = {
      desktop = lib.mkDefault [ "plasma" "hyprland" "wayland" "common" ];
      displayManager = lib.mkDefault [ "ly" ];
      apps = lib.mkDefault [ "media" "gaming" "comms" "productivity" ];
      cli = lib.mkDefault [ "shell" "tools" ];
      development = lib.mkDefault [ "latex" "document-processing" "containers" ];
      services = lib.mkDefault [ "atuin" "ssh" ];
      audio = lib.mkDefault [ "pipewire" ];
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
