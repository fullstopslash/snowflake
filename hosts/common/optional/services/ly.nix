{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Ensure greetd is off when using ly
  services.greetd.enable = lib.mkForce false;

  services.displayManager.ly = {
    enable = true;
    package = pkgs.ly;
    # Prefill username from hostSpec.primaryUsername and disable saving last user
    settings = {
      default_user = config.hostSpec.primaryUsername;
      save = false;
    };
  };
}


