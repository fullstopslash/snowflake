# Hardware Configuration Module
#
# Defines true hardware facts that modules need to query.
# These are physical capabilities of the host, not preferences.
#
# Options:
# - hardware.host.wifi: Hardware has wifi capability
# - hardware.host.persistFolder: Impermanence persist folder path
# - hardware.host.encryption.tpm: TPM-based disk encryption configuration
#
{ config, lib, ... }:
{
  options.hardware.host = {
    wifi = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Hardware has wifi capability (roles: laptop/tablet=true, desktop/server=false)";
    };

    persistFolder = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Impermanence persist folder path (e.g., /persist or /nix/persist)";
      example = "/persist";
    };

    encryption = lib.mkOption {
      type = lib.types.submodule {
        options = {
          tpm = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Enable TPM2-based automatic disk unlock with Clevis (requires TPM 2.0 hardware)";
                };
                pcrIds = lib.mkOption {
                  type = lib.types.str;
                  default = "7";
                  description = "TPM PCR IDs to bind unlock to (default: 7 = Secure Boot state)";
                };
              };
            };
            default = { };
            description = "TPM-based unlock configuration";
          };
        };
      };
      default = { };
      description = "Disk encryption unlock configuration";
    };
  };

  config = {
    assertions = [
      {
        assertion =
          let
            isImpermanent =
              config ? "system" && config.system ? "impermanence" && config.system.impermanence.enable;
          in
          !isImpermanent || (isImpermanent && config.hardware.host.persistFolder != "");
        message = "config.system.impermanence.enable is true but hardware.host.persistFolder is not set";
      }
    ];
  };
}
