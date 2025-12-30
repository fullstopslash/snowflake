# Bcachefs with native encryption and impermanence pattern
#
# Uses separate encrypted bcachefs partitions for impermanence.
# Note: Unlike btrfs which uses subvolumes, bcachefs uses separate partitions.
#
# Architecture:
# - ESP partition (512M, vfat, /boot)
# - persist partition (50%, encrypted bcachefs, /persist)
# - root partition (remaining, encrypted bcachefs, /) - ephemeral
#
# Both partitions use the same passphrase via /tmp/disko-password.
#
# Advantages over LUKS approach:
# - Authenticated encryption with tamper detection
# - Encryption chain of trust and metadata integrity verification
# - Better performance on ARM/mobile hardware
#
# Trade-offs:
# - Two separate encrypted filesystems (same passphrase)
# - No systemd-cryptenroll support (use Clevis for TPM automation)
# - Use bcachefs-luks-impermanence if you need FIDO2/PKCS11 integration
{
  disk ? "/dev/vda",
  persistFolder,
  ...
}:
{
  description = "Bcachefs with native encryption and impermanence";

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
              persist = {
                size = "25G"; # Allocate 25GB to persistent data
                content = {
                  type = "bcachefs";
                  label = "persist"; # Filesystem label for disko
                  # Reference to encrypted filesystem
                  filesystem = "encrypted_persist";
                };
              };
              root = {
                size = "100%"; # Remaining space (25GB) for ephemeral root
                content = {
                  type = "bcachefs";
                  label = "root"; # Filesystem label for disko
                  # Reference to encrypted filesystem
                  filesystem = "encrypted_root";
                };
              };
            };
          };
        };
      };

      # Bcachefs filesystems with native encryption
      bcachefs_filesystems = {
        encrypted_persist = {
          type = "bcachefs_filesystem";
          passwordFile = "/tmp/disko-password";
          extraFormatArgs = [
            # --encrypted is automatically added by disko when passwordFile is set
            "--compression=lz4"
            "--background_compression=lz4"
          ];
          mountpoint = persistFolder;
          mountOptions = [
            "compression=lz4"
            "noatime"
          ];
        };
        encrypted_root = {
          type = "bcachefs_filesystem";
          passwordFile = "/tmp/disko-password";
          extraFormatArgs = [
            # --encrypted is automatically added by disko when passwordFile is set
            "--compression=lz4"
            "--background_compression=lz4"
          ];
          mountpoint = "/";
          mountOptions = [
            "compression=lz4"
            "noatime"
          ];
        };
      };
    };
  };
}
