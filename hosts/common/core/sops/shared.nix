# Shared secrets category: secrets accessible by multiple hosts
#
# These are secrets that need to be shared across hosts, such as:
# - SSH CA keys for host authentication
# - Shared service credentials (backup server, monitoring)
# - Family/shared passwords
# - VPN configurations used by multiple hosts
#
# All hosts with hasSecrets=true can access shared.yaml.
# Role-specific shared secrets should use their respective category files.

{
  lib,
  inputs,
  config,
  ...
}:
let
  sopsFolder = builtins.toString inputs.nix-secrets + "/sops";
  hasSecrets = config.hostSpec.hasSecrets;
in
{
  # Shared secrets are loaded for all hosts with secrets enabled
  # Individual secrets from shared.yaml are defined in their respective
  # category modules (base.nix, desktop.nix, etc.) using:
  #   sopsFile = "${sopsFolder}/shared.yaml";
  #
  # This module exists for any shared secrets that don't fit a specific category,
  # or for future shared secret categories.

  config = lib.mkIf hasSecrets {
    # Currently, shared secrets like passwords/username and passwords/msmtp
    # are defined in base.nix with sopsFile pointing to shared.yaml.
    #
    # Add additional shared secrets here as needed:
    # sops.secrets = {
    #   "shared/some-secret" = {
    #     sopsFile = "${sopsFolder}/shared.yaml";
    #   };
    # };
  };
}
