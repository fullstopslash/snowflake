{ config, lib, ... }:
{
  # Minimal user configuration for installer ISO
  users.users.${config.hostSpec.username} = {
    isNormalUser = true;
    # No password - SSH key auth only (keys added in minimal-configuration.nix)
    hashedPassword = lib.mkForce null;
    extraGroups = [ "wheel" ];
  };
}
