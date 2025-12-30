# Bcachefs with native ChaCha20/Poly1305 encryption
#
# Uses bcachefs native AEAD encryption instead of LUKS block-layer encryption.
# Advantages over LUKS:
# - Authenticated encryption with tamper detection
# - Encryption chain of trust from superblock
# - Metadata integrity verification
# - Better performance on systems without AES-NI (ARM, mobile)
#
# Trade-offs:
# - No systemd-cryptenroll support (requires custom unlock automation)
# - Less mature tooling ecosystem than LUKS
# - Use LUKS variants if you need FIDO2/PKCS11 integration
#
# Security: ChaCha20/Poly1305 provides authenticated encryption (AEAD)
# where each block has a MAC with chain of trust to superblock.
# This protects against tampering and replay attacks that LUKS cannot defend against.
{
  disk ? "/dev/vda",
  ...
}:
{
  # Bcachefs with native encryption

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
                  type = "bcachefs";
                  label = "root"; # Filesystem label for disko
                  # Reference to filesystem defined in bcachefs_filesystems
                  filesystem = "encrypted_root";
                };
              };
            };
          };
        };
      };

      # Bcachefs filesystem with encryption
      bcachefs_filesystems = {
        encrypted_root = {
          type = "bcachefs_filesystem";
          # Enable native ChaCha20/Poly1305 encryption
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
