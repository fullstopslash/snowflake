# Bcachefs with separate /persist partition for impermanence
# Note: Unlike btrfs which uses subvolumes, bcachefs uses separate partitions
{
  disk ? "/dev/vda",
  persistFolder,
  ...
}:
{
  disko.devices = {
    disk = {
      disk0 = {
        type = "disk";
        device = disk;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              start = "1M";
              end = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "defaults" ];
              };
            };
            persist = {
              size = "25G"; # Allocate 25GB to persistent data
              content = {
                type = "filesystem";
                format = "bcachefs";
                mountpoint = persistFolder;
                mountOptions = [
                  "compression=zstd"
                  "noatime"
                ];
              };
            };
            root = {
              size = "100%"; # Remaining space for ephemeral root
              content = {
                type = "filesystem";
                format = "bcachefs";
                mountpoint = "/";
                mountOptions = [
                  "compression=zstd"
                  "noatime"
                ];
              };
            };
          };
        };
      };
    };
  };
}
