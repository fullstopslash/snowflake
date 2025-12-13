# Tablet role - touch-friendly portable device
#
# Uses unified module selection - touch-optimized setup
# Secret categories: base, desktop, network
{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  config = lib.mkIf cfg.tablet {
    # ========================================
    # MODULE SELECTIONS (touch-optimized)
    # ========================================
    modules = {
      desktop = lib.mkDefault [ "wayland" ];
      displayManager = lib.mkDefault [ "ly" ];
      apps = lib.mkDefault [ "media" ];
      cli = lib.mkDefault [ "shell" ];
      development = lib.mkDefault [ ];
      services = lib.mkDefault [ ];
      audio = lib.mkDefault [ "pipewire" ];
    };

    # ========================================
    # TABLET HARDWARE
    # ========================================
    services.libinput.enable = lib.mkDefault true;
    powerManagement.enable = lib.mkDefault true;

    # ========================================
    # HOSTSPEC (non-derived options only)
    # ========================================
    hostSpec = {
      isMobile = lib.mkDefault true;
      wifi = lib.mkDefault true;

      secretCategories = {
        base = lib.mkDefault true;
        desktop = lib.mkDefault true;
        network = lib.mkDefault true;
      };
    };
  };
}
