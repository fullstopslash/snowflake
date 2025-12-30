# Identity Configuration Module
#
# Defines core host and user identity that ALL hosts need.
# This is fundamental information about WHO the machine is and WHO uses it.
#
# Options:
# - identity.hostName: The hostname of the machine
# - identity.primaryUsername: The primary user account
# - identity.users: List of all user accounts
# - identity.home: Home directory path (computed)
# - identity.email: User email addresses
# - identity.domain: Host domain
# - identity.userFullName: User's full name
# - identity.handle: User's handle/username
# - identity.networking: Network configuration
#
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  options.identity = {
    hostName = lib.mkOption {
      type = lib.types.str;
      description = "The hostname of the host (MUST be set by each host)";
      example = "griefling";
    };

    primaryUsername = lib.mkOption {
      type = lib.types.str;
      default = "rain";
      description = "The primary username of the host";
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ config.identity.primaryUsername ];
      description = "A list of all users on the host (defaults to primaryUsername)";
    };

    home = lib.mkOption {
      type = lib.types.str;
      description = "The home directory of the user (auto-computed from primaryUsername)";
      default =
        let
          user = config.identity.primaryUsername;
        in
        if pkgs.stdenv.isLinux then "/home/${user}" else "/Users/${user}";
      readOnly = true;
    };

    email = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "The email of the user (imported from nix-secrets)";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "local";
      description = "The domain of the host (imported from nix-secrets)";
    };

    userFullName = lib.mkOption {
      type = lib.types.str;
      description = "The full name of the user (imported from nix-secrets)";
    };

    handle = lib.mkOption {
      type = lib.types.str;
      default = "fullstopslash";
      description = "The handle of the user";
    };

    networking = lib.mkOption {
      default = { };
      type = lib.types.attrsOf lib.types.anything;
      description = "An attribute set of networking information (imported from nix-secrets)";
    };
  };

  # Set networking.hostName from identity.hostName
  config.networking.hostName = config.identity.hostName;
}
