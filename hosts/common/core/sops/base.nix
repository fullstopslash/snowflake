# Base secrets category: user passwords, age keys, msmtp
#
# These are the minimum secrets needed for any host with hasSecrets=true.
# Includes user password for login, age key for home-manager sops, and msmtp for mail.

{
  lib,
  inputs,
  config,
  ...
}:
let
  sopsFolder = builtins.toString inputs.nix-secrets + "/sops";
  hasSecrets = config.hostSpec.hasSecrets;
  baseEnabled = config.hostSpec.secretCategories.base;
in
{
  config = lib.mkIf (hasSecrets && baseEnabled) {
    sops.secrets = {
      # Age key for home-manager sops - stored in host-specific file (default sopsFile)
      # Secret name maps to nested YAML path keys/age
      "keys/age" = {
        # No sopsFile specified - uses default host-specific file (e.g., griefling.yaml)
        owner = config.users.users.${config.hostSpec.username}.name;
        inherit (config.users.users.${config.hostSpec.username}) group;
        path = "${config.hostSpec.home}/.config/sops/age/keys.txt";
      };

      # User password for login
      # Secret name maps to nested YAML path passwords/<username>
      "passwords/${config.hostSpec.username}" = {
        sopsFile = "${sopsFolder}/shared.yaml";
        neededForUsers = true;
      };

      # msmtp password for system mail
      "passwords/msmtp" = {
        sopsFile = "${sopsFolder}/shared.yaml";
      };
    };

    # Fix ownership of .config/sops directory
    system.activationScripts.sopsSetAgeKeyOwnership =
      let
        ageFolder = "${config.hostSpec.home}/.config/sops/age";
        user = config.users.users.${config.hostSpec.username}.name;
        group = config.users.users.${config.hostSpec.username}.group;
      in
      ''
        mkdir -p ${ageFolder} || true
        chown -R ${user}:${group} ${config.hostSpec.home}/.config
      '';
  };
}
