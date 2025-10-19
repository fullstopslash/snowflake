# Simple greetd display manager configuration
{
  pkgs,
  lib,
  config,
  ...
}: {
  config = {
    # Minimal greetd configuration - no custom appearance or complex settings
    services.greetd = {
      enable = true;
      restart = true;
      settings = {
        default_session = {
          command = "${pkgs.cage}/bin/cage -s -- ${pkgs.qtgreet}/bin/qtgreet";
          user = "rain";
        };
      };
    };

    # Disable SDDM to avoid conflicts (force override stylix configuration)
    services.displayManager.sddm.enable = lib.mkForce false;
  };
}
