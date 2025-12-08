{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  # Raspberry Pi - aarch64, headless by default
  imports = [
    ../modules/apps/cli
    ../modules/services/networking
  ];

  # Pi-specific config
  config = lib.mkIf cfg.pi {
    # Pi-specific bootloader
    boot.loader.grub.enable = lib.mkDefault false;
    boot.loader.generic-extlinux-compatible.enable = lib.mkDefault true;

    # Minimal footprint
    documentation.enable = lib.mkDefault false;
    services.openssh.enable = lib.mkDefault true;
  };
}
