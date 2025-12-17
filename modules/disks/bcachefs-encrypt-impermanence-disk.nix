# Bcachefs with native encryption and impermanence pattern
#
# Uses separate encrypted partitions for persistent and ephemeral data.
# Both partitions use native ChaCha20/Poly1305 encryption.
#
# Architecture:
# - ESP partition (512M, vfat, /boot)
# - Encrypted bcachefs persist partition (50%, for persistent data)
# - Encrypted bcachefs root partition (50%, ephemeral)
#
# Advantages over LUKS approach:
# - Each partition independently encrypted with authenticated encryption
# - Encryption chain of trust and metadata integrity verification
# - Tamper detection on both persistent and ephemeral filesystems
# - Better performance on ARM/mobile hardware
#
# Trade-offs:
# - Requires unlocking both partitions at boot (two passphrases or automation)
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
            persist = {
              size = "50%"; # Allocate half the disk to persistent data
              content = {
                type = "filesystem";
                format = "bcachefs";
                # Enable native encryption on persist partition
                extraFormatArgs = [
                  "--encrypted"
                  "--compression=lz4"
                  "--background_compression=lz4"
                ];
                # Password from /tmp/disko-password (Phase 17 compatibility)
                passwordFile = "/tmp/disko-password";
                mountpoint = persistFolder;
                mountOptions = [
                  "compression=lz4"
                  "noatime"
                ];
              };
            };
            root = {
              size = "100%"; # Remaining space for ephemeral root
              content = {
                type = "filesystem";
                format = "bcachefs";
                # Enable native encryption on root partition
                extraFormatArgs = [
                  "--encrypted"
                  "--compression=lz4"
                  "--background_compression=lz4"
                ];
                # Password from /tmp/disko-password (Phase 17 compatibility)
                # Note: Both partitions will use same password during format
                passwordFile = "/tmp/disko-password";
                mountpoint = "/";
                mountOptions = [
                  "compression=lz4"
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
