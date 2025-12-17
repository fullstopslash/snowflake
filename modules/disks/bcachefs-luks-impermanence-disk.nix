# Bcachefs with LUKS encryption and separate /persist partition
# Combines LUKS encryption with impermanence pattern using LVM
# LVM allows flexible partition sizing within encrypted container
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
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "encrypted-nixos";
                passwordFile = "/tmp/disko-password";
                settings = {
                  allowDiscards = true;
                  # FIDO2/YubiKey support removed - password-only unlock
                  # YubiKey can be added post-install via: systemd-cryptenroll --fido2-device=auto /dev/device
                };
                content = {
                  type = "lvm_pv";
                  vg = "pool";
                };
              };
            };
          };
        };
      };
    };
    lvm_vg = {
      pool = {
        type = "lvm_vg";
        lvs = {
          persist = {
            size = "50%"; # Half the space for persistent data
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
            size = "100%FREE"; # Remaining space for ephemeral root
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
}
