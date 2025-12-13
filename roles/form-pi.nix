# Pi role - Raspberry Pi (aarch64, headless by default)
#
# Uses unified module selection - minimal headless setup
# Secret categories: base, network
{ config, lib, ... }:
{
  config = lib.mkIf (builtins.elem "pi" config.roles) {
    # ========================================
    # MODULE SELECTIONS (minimal headless)
    # ========================================
    # Paths mirror filesystem: modules/<top>/<category> = [ "<module>" ]
    modules = {
      apps = {
        cli = [
          "shell"
          "tools"
        ];
      };
      services = {
        networking = [ "openssh" ];
      };
    };

    # ========================================
    # PI BOOTLOADER
    # ========================================
    boot.loader.grub.enable = lib.mkDefault false;
    boot.loader.generic-extlinux-compatible.enable = lib.mkDefault true;
    documentation.enable = lib.mkDefault false;

    # ========================================
    # HOSTSPEC (non-derived options only)
    # ========================================
    hostSpec = {
      isProduction = lib.mkDefault true;
      wifi = lib.mkDefault true;

      secretCategories = {
        base = lib.mkDefault true;
        network = lib.mkDefault true;
      };
    };
  };
}
