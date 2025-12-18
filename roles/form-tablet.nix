# Tablet role - touch-friendly portable device
#
# Uses unified module selection - touch-optimized setup
# Secret categories: base, desktop, network
{ config, lib, ... }:
{
  config = lib.mkIf (builtins.elem "tablet" config.roles) {
    # ========================================
    # MODULE SELECTIONS (touch-optimized)
    # ========================================
    # Paths mirror filesystem: modules/<top>/<category> = [ "<module>" ]
    modules = {
      apps = {
        media = [ "media" ];
        desktop = [ "wayland" ];
        cli = [
          "comma"
          "shell"
        ];
      };
      services = {
        display-manager = [ "ly" ];
        audio = [ "pipewire" ];
      };
    };

    # ========================================
    # TABLET HARDWARE
    # ========================================
    services.libinput.enable = lib.mkDefault true;
    powerManagement.enable = lib.mkDefault true;

    # ========================================
    # HOSTSPEC (non-derived options only)
    # ========================================
    host = {
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
