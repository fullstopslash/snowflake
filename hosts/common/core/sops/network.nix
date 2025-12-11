# Network secrets category: VPN and network service credentials
#
# Includes Tailscale OAuth credentials, Syncthing device IDs, and other network-related secrets.

{
  lib,
  inputs,
  config,
  ...
}:
let
  sopsFolder = builtins.toString inputs.nix-secrets + "/sops";
  hasSecrets = config.hostSpec.hasSecrets;
  networkEnabled = config.hostSpec.secretCategories.network;
in
{
  config = lib.mkIf (hasSecrets && networkEnabled) {
    sops.secrets = {
      # Tailscale OAuth for automatic authentication
      # Secret name maps to nested YAML path tailscale/oauth_client_id
      "tailscale/oauth_client_id" = {
        sopsFile = "${sopsFolder}/shared.yaml";
        owner = "root";
      };
      "tailscale/oauth_client_secret" = {
        sopsFile = "${sopsFolder}/shared.yaml";
        owner = "root";
      };

      # Syncthing device IDs
      "syncthing_waterbug_id" = {
        sopsFile = "${sopsFolder}/shared.yaml";
        owner = config.hostSpec.username;
      };
      "syncthing_pixel_id" = {
        sopsFile = "${sopsFolder}/shared.yaml";
        owner = config.hostSpec.username;
      };
    };
  };
}
