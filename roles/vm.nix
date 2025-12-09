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

    # VM secret categories (base only)
    hostSpec.secretCategories = {
      base = lib.mkDefault true;
    };
  };
}
