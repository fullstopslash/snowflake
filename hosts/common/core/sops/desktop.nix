# Desktop secrets category: application secrets for desktop environments
#
# Includes secrets for desktop apps like Home Assistant integration,
# and services that are desktop-specific.

{
  lib,
  inputs,
  config,
  ...
}:
let
  sopsFolder = builtins.toString inputs.nix-secrets + "/sops";
  hasSecrets = config.hostSpec.hasSecrets;
  desktopEnabled = config.hostSpec.secretCategories.desktop;
in
{
  config = lib.mkIf (hasSecrets && desktopEnabled) {
    sops.secrets = {
      # Home Assistant integration for desktop services
      env_hass_server = {
        key = "env_hass_server";
        sopsFile = "${sopsFolder}/shared.yaml";
      };
      env_hass_token = {
        key = "env_hass_token";
        sopsFile = "${sopsFolder}/shared.yaml";
      };
    };

    # Template for services that need HASS env vars
    sops.templates."hass.env" = {
      content = ''
        HASS_SERVER=${config.sops.placeholder."env_hass_server"}
        HASS_TOKEN=${config.sops.placeholder."env_hass_token"}
      '';
      owner = config.hostSpec.username;
      mode = "0400";
    };
  };
}
