# Pi role - Raspberry Pi (aarch64, headless by default)
#
# Enables: CLI tools, networking, SSH
# Disables: Documentation, GRUB (uses extlinux)
# Designed for: Raspberry Pi 3/4/5
{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  # Pi-specific config
  config = lib.mkIf cfg.pi {
    # Pi-specific bootloader
    boot.loader.grub.enable = lib.mkDefault false;
    boot.loader.generic-extlinux-compatible.enable = lib.mkDefault true;

    # Minimal footprint
    documentation.enable = lib.mkDefault false;
    services.openssh.enable = lib.mkDefault true;

    # Pi hostSpec defaults - hosts can override with lib.mkForce
    hostSpec = {
      # Behavioral defaults specific to Pi
      isMinimal = lib.mkDefault true; # Pi is minimal/headless
      useWayland = lib.mkDefault false; # Headless
      useWindowManager = lib.mkDefault false; # No GUI
      isDevelopment = lib.mkDefault false; # Not a dev workstation
      isMobile = lib.mkDefault false; # Pis are stationary
      isProduction = lib.mkDefault true; # Pi hosts are often production (home servers)
      wifi = lib.mkDefault true; # Many Pis have wifi

      # Pi secret categories
      secretCategories = {
        base = lib.mkDefault true;
        network = lib.mkDefault true; # Pis often run network services
      };
    };
  };
}
