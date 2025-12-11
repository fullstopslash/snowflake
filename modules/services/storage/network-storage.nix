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
    # Using systemd.mounts instead of fileSystems for better control and clarity
    systemd.mounts =
      let
        commonMountOptions = {
          type = "nfs";
          mountConfig = {
            Options = [
              "noatime" # Don't update access times (performance)
              "nfsvers=4.2" # Use NFSv4.2 protocol
              # "hard" # Commented out - soft mounts allow boot to continue if server unavailable
            ];
            TimeoutSec = "30"; # Give up after 30 seconds if server unreachable
          };
        };
      in
      [
        # Main storage pool
        (
          commonMountOptions
          // {
            what = "waterbug.lan:/mnt/storage/storage";
            where = "/storage";
          }
        )
        # Applications directory
        (
          commonMountOptions
          // {
            what = "waterbug.lan:/mnt/apps/apps";
            where = "/mnt/apps";
          }
        )
      ];

    # Configure automount behavior for NFS shares
    # Mounts on first access, unmounts after idle timeout
    systemd.automounts =
      let
        commonAutoMountOptions = {
          wantedBy = [ "multi-user.target" ]; # Start automatically at boot
          automountConfig = {
            TimeoutIdleSec = "600"; # Unmount after 10 minutes of inactivity
          };
        };
      in
      [
        (commonAutoMountOptions // { where = "/storage"; })
        (commonAutoMountOptions // { where = "/mnt/apps"; })
      ];
  };
}
