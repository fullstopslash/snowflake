# Secrets role
{ pkgs, ... }:
{
  description = "secrets management tools";
  config = {
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
