# Simple greetd display manager configuration with tuigreet (more reliable)
{
  pkgs,
  lib,
  config,
  ...
}: {
  config = {
    # Minimal greetd configuration using tuigreet (TUI greeter - more reliable)
    services.greetd = {
      enable = true;
      restart = true;
      settings = {
        default_session = {
          # Always show login screen - tuigreet will prompt for password
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
          user = "rain";
        };
      };
    };

    # Disable SDDM to avoid conflicts (force override stylix configuration)
    services.displayManager.sddm.enable = lib.mkForce false;
  };
}
