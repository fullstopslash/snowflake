# Fast test role - absolute minimum for deployment testing
{ config, lib, pkgs, ... }:
let cfg = config.roles; in {
  config = lib.mkIf cfg.fastTest {
    # Override any heavy defaults
    myModules = {
      apps.gaming.enable = lib.mkForce false;
      apps.media.enable = lib.mkForce false;
      desktop.plasma.enable = lib.mkForce false;
      services.development.containers.enable = lib.mkForce false;
      apps.development.latex.enable = lib.mkForce false;
      apps.cli.tools.enable = lib.mkForce false;
    };

    # Minimal test packages only
    environment.systemPackages = with pkgs; [
      git
      curl
      htop
    ];

    # Disable documentation
    documentation.enable = false;
    documentation.man.enable = false;
    documentation.nixos.enable = false;
  };
}
