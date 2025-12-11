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
      # Secret name maps to nested YAML path hass/server
      "hass/server" = {
        sopsFile = "${sopsFolder}/shared.yaml";
      };
      "hass/token" = {
        sopsFile = "${sopsFolder}/shared.yaml";
      };
    };

    # Template for services that need HASS env vars
    sops.templates."hass.env" = {
      content = ''
        HASS_SERVER=${config.sops.placeholder."hass/server"}
        HASS_TOKEN=${config.sops.placeholder."hass/token"}
      '';
      owner = config.hostSpec.username;
      mode = "0400";
    };
  };
}
