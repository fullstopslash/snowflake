# Server secrets category: service credentials for server roles
#
# Includes secrets for backup services, databases, and other
# server-specific credentials.

{
  pkgs,
  lib,
  inputs,
  config,
  ...
}:
let
  sopsFolder = builtins.toString inputs.nix-secrets + "/sops";
  hasSecrets = config.hostSpec.hasSecrets;
  serverEnabled = config.hostSpec.secretCategories.server;
in
{
  config = lib.mkIf (hasSecrets && serverEnabled) {
    sops.secrets = lib.mkMerge [
      # Borg backup password (only if backup service enabled)
      (lib.mkIf config.services.backup.enable {
        "passwords/borg" = {
          owner = "root";
          group = if pkgs.stdenv.isLinux then "root" else "wheel";
          mode = "0600";
          path = "/etc/borg/passphrase";
        };

        "keys/ssh/borg" = {
          owner = "root";
          group = if pkgs.stdenv.isLinux then "root" else "wheel";
          path = "${config.users.users.root.home}/.ssh/id_borg";
        };
      })
    ];
  };
}
