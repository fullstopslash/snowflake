# ly display manager - TUI login with theming support
{
  pkgs,
  lib,
  config,
  ...
}: {
  config = {
    services.displayManager.ly = {
      enable = true;
      settings = {
        # Default session command
        default_session_name = "Hyprland";
      };
    };

    # Disable other display managers to avoid conflicts
    services.greetd.enable = lib.mkForce false;
    services.displayManager.sddm.enable = lib.mkForce false;
  };
}
