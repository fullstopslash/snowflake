# Desktop role - full graphical workstation
#
# Enables: GUI desktop environment, audio, media apps, gaming, development tools
# Sets: useWayland, useWindowManager, isDevelopment hostSpec values
# Secret categories: base, desktop, network
{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  # Module imports - always evaluated, functionality controlled by enable options
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
    ../modules/services/storage
    ../modules/services/misc
    ../modules/services/ai

    # Desktop-relevant optional modules (files that exist)
    (lib.custom.relativeToRoot "hosts/common/optional/hyprland.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/wayland.nix")
  ];

  # Config options are conditional on role being enabled
  config = lib.mkIf cfg.desktop {
    # Desktop-specific defaults
    services.xserver.enable = lib.mkDefault true;
    hardware.graphics.enable = lib.mkDefault true;

    # Desktop hostSpec defaults - hosts can override with lib.mkForce
    hostSpec = {
      # Behavioral defaults specific to desktop
      useWayland = lib.mkDefault true;
      useWindowManager = lib.mkDefault true;
      isDevelopment = lib.mkDefault true;
      isMobile = lib.mkDefault false; # Desktops are not mobile
      wifi = lib.mkDefault false; # Desktops typically use ethernet
      isMinimal = lib.mkDefault false; # Full desktop environment

      # Desktop secret categories
      secretCategories = {
        base = lib.mkDefault true;
        desktop = lib.mkDefault true;
        network = lib.mkDefault true;
        cli = lib.mkDefault true; # Desktop users typically use CLI tools like atuin
      };
    };
  };
}
