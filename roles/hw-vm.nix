# VM role - minimal virtual machine for testing
#
# Enables: CLI tools, QEMU guest tools, SPICE agent
# Disables: Documentation, minimal secrets
# Sets: fast boot, minimal timeout
# Secret categories: base only
{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  # Virtual machine - minimal for testing
  imports = [
    ../modules/apps/cli
  ];

  # VM-specific config
  config = lib.mkIf cfg.vm {
    # VM guest tools
    services.qemuGuest.enable = lib.mkDefault true;
    services.spice-vdagentd.enable = lib.mkDefault true;

    # Minimal configuration
    documentation.enable = lib.mkDefault false;
    boot.loader.timeout = lib.mkDefault 1;

    # VM hostSpec defaults - hosts can override with lib.mkForce
    hostSpec = {
      # Behavioral defaults specific to VM
      isMinimal = lib.mkDefault true; # VMs are minimal by default
      isProduction = lib.mkDefault false; # VMs are for testing
      hasSecrets = lib.mkDefault false; # VMs typically don't have secrets
      useWayland = lib.mkDefault false; # Minimal VMs don't use Wayland
      useWindowManager = lib.mkDefault false; # Minimal VMs are headless
      isDevelopment = lib.mkDefault false; # Not a dev workstation
      isMobile = lib.mkDefault false; # VMs are not mobile
      wifi = lib.mkDefault false; # VMs use virtual networking

      # VM secret categories (minimal - hosts can override if needed)
      secretCategories = {
        base = lib.mkDefault false; # VMs typically don't have secrets
      };
    };
  };
}
