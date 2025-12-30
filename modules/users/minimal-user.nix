{ config, lib, ... }:
{
  # Minimal user configuration for installer/bootstrap

  # Minimal user configuration for installer/bootstrap
  # Uses empty password for LY console login - SSH uses key auth
  #
  # Password precedence with mutableUsers = false:
  #   initialHashedPassword -> hashedPassword -> initialPassword -> password -> hashedPasswordFile
  # We must clear hashedPasswordFile (set by users/default.nix) to let initialPassword work
  config = {
    users = {
      mutableUsers = lib.mkForce false;
      users.${config.identity.primaryUsername} = {
        isNormalUser = true;
        # Clear hashedPasswordFile from users/default.nix (empty string "" causes locked account)
        hashedPasswordFile = lib.mkForce null;
        # Empty string = empty password (can login by pressing Enter)
        # This is safe for local test VMs only
        initialPassword = lib.mkForce "";
        extraGroups = [ "wheel" ];
      };
      users.root = {
        # Clear any hashedPasswordFile inherited from primary user
        hashedPasswordFile = lib.mkForce null;
        # Allow root login with empty password for bootstrap
        initialPassword = lib.mkForce "";
      };
    };
  };
}
