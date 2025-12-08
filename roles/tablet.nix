{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  # Tablet - touch-friendly desktop
  imports = [
    ../modules/services/desktop
    ../modules/services/audio
    ../modules/apps/cli
    ../modules/apps/fonts
    ../modules/apps/media
  ];

  # Tablet-specific config
  config = lib.mkIf cfg.tablet {
    # Touch input
    services.libinput.enable = lib.mkDefault true;

    # On-screen keyboard
    # programs.squeekboard.enable = lib.mkDefault true;  # if available

    # Power management
    powerManagement.enable = lib.mkDefault true;
  };
}
