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
        # Save session selection (default, but explicit)
        save = true;
        # Focus session selector on startup so user sees options
        default_input = "session";
      };
    };

    # Disable other display managers to avoid conflicts
    services.greetd.enable = lib.mkForce false;
    services.displayManager.sddm.enable = lib.mkForce false;
  };
}
