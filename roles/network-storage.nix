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

  # NFS mounts with boot optimizations
  # Moved from /storage to /mnt/storage to avoid bwrap/autofs issues with Steam FHS environment
  fileSystems."/mnt/storage" = {
    device = "waterbug.lan:/mnt/storage/storage";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "nfsvers=4.2"
      "rsize=1048576"
      "wsize=1048576"
      # "hard"
      "intr"
      "timeo=14"
      # "noatime"
      "lookupcache=positive"
      "noauto"
      "user"
      "x-systemd.idle-timeout=0"
      "x-systemd.device-timeout=30"
    ];
  };
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
      mountConfig = {
        Options = [
          "noatime"
          "nfsvers=4.2"
          # "hard"
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
      automountConfig = {
        TimeoutIdleSec = "600";
      };
    };
  in [
    (commonAutoMountOptions // {where = "/mnt/storage";})
    (commonAutoMountOptions // {where = "/mnt/apps";})
  ];
}
