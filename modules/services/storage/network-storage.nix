# Network storage module - NFS mounts for LAN storage access
#
# Provides automounted NFS shares from waterbug.lan storage server:
# - /storage - Main storage pool
# - /mnt/apps - Applications and shared software
#
# Uses systemd automount to avoid boot delays when storage server is unavailable.
#
# Enable via: services.networkStorage.enable = true;
# Or import: hosts/common/optional/network-storage.nix
{
  config,
  lib,
  ...
}:
let
  cfg = config.services.networkStorage;
in
{
  options.services.networkStorage = {
    enable = lib.mkEnableOption "Enable network storage NFS mounts";
  };

  config = lib.mkIf cfg.enable {
    # Enable NFS client support
    services.rpcbind.enable = true;
    boot.supportedFilesystems = [ "nfs" ];

    # Define systemd mounts for NFS shares
    systemd.mounts =
      let
        commonMountOptions = {
          type = "nfs";
          mountConfig = {
            Options = [
              "noatime"
              "nfsvers=3"
            ];
            TimeoutSec = "30";
          };
        };
      in
      [
        (
          commonMountOptions
          // {
            what = "waterbug.lan:/mnt/storage/storage";
            where = "/storage";
          }
        )
        (
          commonMountOptions
          // {
            what = "waterbug.lan:/mnt/apps/apps";
            where = "/mnt/apps";
          }
        )
      ];

    # Configure automount behavior for NFS shares
    systemd.automounts =
      let
        commonAutoMountOptions = {
          wantedBy = [ "multi-user.target" ];
          automountConfig = {
            TimeoutIdleSec = "600";
          };
        };
      in
      [
        (commonAutoMountOptions // { where = "/storage"; })
        (commonAutoMountOptions // { where = "/mnt/apps"; })
      ];
  };
}
