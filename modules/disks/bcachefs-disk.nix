# Simple bcachefs layout - no encryption, no impermanence
# Just EFI + single bcachefs root partition
{
  disk ? "/dev/vda",
  ...
}:
{
  # Simple Bcachefs filesystem layout

  config = {
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
              root = {
                size = "100%";
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
  };
}
