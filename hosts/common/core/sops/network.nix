# Network secrets category: VPN and network service credentials
#
# Includes Tailscale OAuth credentials and other network-related secrets.

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
      "tailscale/oauth_client_id" = {
        key = "tailscale_oauth_client_id";
        sopsFile = "${sopsFolder}/shared.yaml";
        owner = "root";
      };
      "tailscale/oauth_client_secret" = {
        key = "tailscale_oauth_client_secret";
        sopsFile = "${sopsFolder}/shared.yaml";
        owner = "root";
      };
    };
  };
}
