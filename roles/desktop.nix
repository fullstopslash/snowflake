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

    # Desktop-relevant optional modules
    # These provide additional desktop functionality
    (lib.custom.relativeToRoot "hosts/common/optional/audio.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/fonts.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/gaming.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/hyprland.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/wayland.nix")
    # stylix.nix requires inputs.stylix - hosts must import it with the stylix NixOS module
    (lib.custom.relativeToRoot "hosts/common/optional/thunar.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/vlc.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/plymouth.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/services/greetd.nix")
  ];

  # Config options are conditional
  config = lib.mkIf cfg.desktop {
    # Desktop-specific defaults
    services.xserver.enable = lib.mkDefault true;
    hardware.graphics.enable = lib.mkDefault true;

    # Desktop hostSpec defaults - hosts can override with lib.mkForce
    hostSpec = {
      useWayland = lib.mkDefault true;
      useWindowManager = lib.mkDefault true;
      isDevelopment = lib.mkDefault true;
      # Desktop secret categories
      secretCategories = {
        base = lib.mkDefault true;
        desktop = lib.mkDefault true;
        network = lib.mkDefault true;
      };
    };
  };
}
