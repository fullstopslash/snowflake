# Bcachefs with native encryption and impermanence pattern
#
# Uses bcachefs subvolumes for impermanence (like btrfs @root/@persist pattern).
# Entire partition is encrypted with ChaCha20/Poly1305.
#
# Architecture:
# - ESP partition (512M, vfat, /boot)
# - Encrypted bcachefs partition with subvolumes:
#   - @root subvolume (ephemeral, wiped on boot)
#   - @persist subvolume (persistent data)
#
# Advantages over LUKS approach:
# - Authenticated encryption with tamper detection
# - Encryption chain of trust and metadata integrity verification
# - Single passphrase for all subvolumes
# - Better performance on ARM/mobile hardware
#
# Trade-offs:
# - No systemd-cryptenroll support (use Clevis for TPM automation)
# - Use bcachefs-luks-impermanence if you need FIDO2/PKCS11 integration
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
            root = {
              size = "100%";
              content = {
                type = "bcachefs";
                # Reference to filesystem defined in bcachefs_filesystems
                filesystem = "encrypted_impermanence";
              };
            };
          };
        };
      };
    };

    # Bcachefs filesystem with encryption and subvolumes
    bcachefs_filesystems = {
      encrypted_impermanence = {
        type = "bcachefs_filesystem";
        # Enable native ChaCha20/Poly1305 encryption
        passwordFile = "/tmp/disko-password";
        extraFormatArgs = [
          "--encrypted"
          "--compression=lz4"
          "--background_compression=lz4"
        ];
        # Subvolumes for impermanence pattern
        subvolumes = {
          "@root" = {
            mountpoint = "/";
            mountOptions = [
              "compression=lz4"
              "noatime"
            ];
          };
          "@persist" = {
            mountpoint = persistFolder;
            mountOptions = [
              "compression=lz4"
              "noatime"
            ];
          };
        };
      };
    };
  };
}
