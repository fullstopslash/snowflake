# Simple greetd display manager configuration with tuigreet (more reliable)
# Uses mkDefault so host-specific greetd configs can override
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.myModules.displayManager.greetd;
in
{
  options.myModules.displayManager.greetd = {
    enable = lib.mkEnableOption "greetd display manager with tuigreet";
  };

  config = lib.mkIf cfg.enable {
    # Minimal greetd configuration using tuigreet (TUI greeter - more reliable)
    services.greetd = {
      enable = true;
      restart = lib.mkDefault true;
      settings = {
        default_session = {
          # Always show login screen - tuigreet will prompt for password
          command = lib.mkDefault "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland";
          # user defaults to "greeter" from upstream NixOS module, leave as default
        };
      };
    };

    # Disable SDDM to avoid conflicts (force override stylix configuration)
    services.displayManager.sddm.enable = lib.mkForce false;
  };
}
