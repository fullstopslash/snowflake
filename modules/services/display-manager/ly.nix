# Ly display manager module
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.services.displayManager.ly;
in
{
  options.myModules.services.displayManager.ly = {
    enable = lib.mkEnableOption "Ly display manager";
    tty = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "TTY number for Ly display manager";
    };
  };

  config = lib.mkIf cfg.enable {
    # Disable other display managers when using Ly
    services.greetd.enable = lib.mkForce false;
    services.displayManager.sddm.enable = lib.mkForce false;

    # Ensure the animation tool is available when ly is enabled
    environment.systemPackages = [ pkgs.neo ];

    services.displayManager.ly = {
      enable = true;
      package = pkgs.ly;
      settings = {
        default_user = lib.mkDefault config.hostSpec.primaryUsername;
        save = lib.mkDefault false;
        animate = lib.mkDefault true;
        animation = lib.mkDefault "3";
        tty = lib.mkDefault cfg.tty;
      };
    };
  };
}
