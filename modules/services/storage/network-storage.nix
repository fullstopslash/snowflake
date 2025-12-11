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

    # Strategy:
    # - Mount NFSv4 pseudoroot at /mnt/waterbug
    # - Bind-mount desired subdirectories to stable targets
    #
    # This avoids v3 export permission issues and v4 subpath restrictions,
    # while keeping user-facing paths unchanged.
    systemd.mounts =
      let
        # Mount the NFSv4 pseudoroot
        rootMount = {
          type = "nfs4";
          what = "waterbug.lan:/";
          where = "/mnt/waterbug";
          mountConfig = {
            Options = [
              "noatime"
              "nfsvers=4"
              "sec=sys"
            ];
            TimeoutSec = "30";
          };
          wantedBy = [ "multi-user.target" ];
        };

        # Bind mount a subdirectory from the NFS root to a target
        bindMount =
          {
            from,
            to,
          }:
          {
            type = "none";
            what = from;
            where = to;
            mountConfig = {
              Options = [ "bind" ];
              # Ensure the NFS root is mounted prior to bind
              Requires = [ "mnt-waterbug.mount" ];
              After = [ "mnt-waterbug.mount" ];
              TimeoutSec = "30";
            };
          };
      in
      [
        rootMount
        (bindMount {
          from = "/mnt/waterbug/mnt/storage/storage";
          to = "/storage";
        })
        (bindMount {
          from = "/mnt/waterbug/mnt/apps/apps";
          to = "/mnt/apps";
        })
      ];

    # Automounts for laziness and to avoid boot delays
    systemd.automounts =
      let
        commonAuto = {
          wantedBy = [ "multi-user.target" ];
          automountConfig.TimeoutIdleSec = "600";
        };
      in
      [
        # Automount the NFS root (so bind mounts can pull it in)
        # Automount user-facing bind mounts
        (commonAuto // { where = "/storage"; })
        (commonAuto // { where = "/mnt/apps"; })
      ];
  };
}
