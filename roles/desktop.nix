{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  # Imports are at top level - always evaluated
  # Modules themselves have enable options that are set conditionally below
  imports = [
    # Desktop environment
    ../modules/services/desktop
    ../modules/services/audio

    # Applications
    ../modules/apps/cli
    ../modules/apps/fonts
    ../modules/apps/media
    ../modules/apps/gaming
    ../modules/apps/theming
    ../modules/apps/development

    # Services
    ../modules/services/networking
    ../modules/services/development
    ../modules/services/security
    ../modules/services/ai
  ];

  # Config options are conditional
  config = lib.mkIf cfg.desktop {
    # Desktop-specific defaults
    services.xserver.enable = lib.mkDefault true;
    hardware.graphics.enable = lib.mkDefault true;
  };
}
