# Secrets role
{ config, pkgs, lib, ... }:
let
  cfg = config.myModules.services.security.secrets;
in
{
  options.myModules.services.security.secrets = {
    enable = lib.mkEnableOption "secrets management tools";
  };

  config = lib.mkIf cfg.enable {
    # Secrets packages
    environment.systemPackages = with pkgs; [
      # Secrets management
      age
      age-plugin-yubikey
      sops
      gopass
      pass
      gnupg
      ssh-to-age
      rbw
      bitwarden-cli
      bitwarden-desktop
      # bws
    ];
  };
}
