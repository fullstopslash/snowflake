# Ly display manager module
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.desktop.ly;
in
{
  options.myModules.desktop.ly = {
    enable = lib.mkEnableOption "Ly display manager";
  };

  config = lib.mkIf cfg.enable {
    # Ensure greetd is off when using ly
    services.greetd.enable = lib.mkForce false;

    # Ensure the animation tool is available when ly is enabled
    environment.systemPackages = [ pkgs.neo ];

    services.displayManager.ly = {
      enable = true;
      package = pkgs.ly;
      # Prefill username from hostSpec.primaryUsername and disable saving last user
      settings = {
        default_user = config.hostSpec.primaryUsername;
        save = false;
        animate = true;
        animation = "3";
        # Run custom animation command (requires 'neo' in PATH)
        # cmd = "neo --chars=10450,1047F --defaultbg -c cyan";
      };
    };
  };
}
