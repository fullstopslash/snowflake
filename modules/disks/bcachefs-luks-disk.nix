# Bcachefs with LUKS encryption
# Uses LUKS for encryption (compatible with Phase 17 infrastructure)
# Note: Bcachefs has native encryption, but LUKS provides compatibility
# with existing password management and key rotation workflows
{
  disk ? "/dev/vda",
  ...
}:
{
  # Bcachefs filesystem with LUKS encryption

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
  };
}
