# Network storage role
_: {
  # NFS support
  services.rpcbind.enable = true;
  boot.supportedFilesystems = ["nfs"];

  # # Security wrappers for mount/umount
  # security.wrappers.mount = {
  #   owner = "root";
  #   group = "root";
  #   setuid = true;
  #   source = "${pkgs.util-linux}/bin/mount";
  # };
  #
  # security.wrappers.umount = {
  #   owner = "root";
  #   group = "root";
  #   setuid = true;
  #   source = "${pkgs.util-linux}/bin/umount";
  # };

  # NFS mounts configured via systemd.mounts below
  # (Removed old fileSystems."/mnt/storage" - now using systemd.mounts approach)
  #
  # fileSystems."/mnt/apps" = {
  #   device = "waterbug.lan:/mnt/apps/apps";
  #   fsType = "nfs";
  #   options = [
  #     "x-systemd.automount"
  #     "nfsvers=4.2"
  #     "rsize=1048576"
  #     "wsize=1048576"
  #     "hard"
  #     "intr"
  #     "timeo=14"
  #     "noatime"
  #     "lookupcache=positive"
  #     "noauto"
  #     "user"
  #     "x-systemd.idle-timeout=0"
  #     "x-systemd.device-timeout=30"
  #   ];
  # };
  systemd.mounts = let
    commonMountOptions = {
      type = "nfs";
      unitConfig = {
        After = "network-online.target nss-lookup.target";
        Requires = "network-online.target";
        # Allow retries on failure
        StartLimitIntervalSec = 60;
        StartLimitBurst = 5;
      };
      mountConfig = {
        Options = [
          "noatime"
          "nfsvers=4.2"
          "soft" # fail gracefully instead of hanging
          "retrans=3" # retry 3 times before failing
          "timeo=30" # 3 second timeout per retry
        ];
        TimeoutSec = "30";
      };
    };
  in [
    (commonMountOptions
      // {
        what = "waterbug.lan:/mnt/apps/apps";
        where = "/mnt/apps";
      })
    (commonMountOptions
      // {
        what = "waterbug.lan:/mnt/storage/storage";
        where = "/mnt/storage";
      })
  ];

  systemd.automounts = let
    commonAutoMountOptions = {
      wantedBy = ["multi-user.target"];
      unitConfig = {
        # Don't give up permanently on failure
        StartLimitIntervalSec = 0;
      };
      automountConfig = {
        TimeoutIdleSec = "600";
      };
    };
  in [
    (commonAutoMountOptions // {where = "/mnt/storage";})
    (commonAutoMountOptions // {where = "/mnt/apps";})
  ];
}
