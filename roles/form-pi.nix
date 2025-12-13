# Pi role - Raspberry Pi (aarch64, headless by default)
#
# Uses unified module selection - minimal headless setup
# Secret categories: base, network
{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  config = lib.mkIf cfg.pi {
    # ========================================
    # MODULE SELECTIONS (minimal headless)
    # ========================================
    modules = {
      desktop = lib.mkDefault [ ];
      displayManager = lib.mkDefault [ ];
      apps = lib.mkDefault [ ];
      cli = lib.mkDefault [ "shell" "tools" ];
      development = lib.mkDefault [ ];
      services = lib.mkDefault [ "openssh" "auto-upgrade" ];
      audio = lib.mkDefault [ ];
    };

    # ========================================
    # PI BOOTLOADER
    # ========================================
    boot.loader.grub.enable = lib.mkDefault false;
    boot.loader.generic-extlinux-compatible.enable = lib.mkDefault true;
    documentation.enable = lib.mkDefault false;
    services.openssh.enable = lib.mkDefault true;

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
