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
    # Prefill username from hostSpec.primaryUsername; use [main] section
    settings = {
      main = {
        default_user = config.hostSpec.primaryUsername;
        # Ensure default_user is used instead of last saved user
        save = false;
      };
    };
  };
}


