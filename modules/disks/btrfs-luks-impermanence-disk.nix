# NOTE: ... is needed because dikso passes diskoFile
{
  lib,
  disk ? "/dev/vda",
  withSwap ? false,
  swapSize,
  config,
  ...
}:
{
  # Btrfs filesystem with LUKS encryption and impermanence

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
                size = "512M";
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
                  passwordFile = "/tmp/disko-password"; # this is populated by bootstrap-nixos.sh
                  settings = {
                    allowDiscards = true;
                    # FIDO2/YubiKey support removed - password-only unlock
                    # YubiKey can be added post-install via: systemd-cryptenroll --fido2-device=auto /dev/device
                  };
                  # Subvolumes must set a mountpoint in order to be mounted,
                  # unless their parent is mounted
                  content = {
                    type = "btrfs";
                    extraArgs = [ "-f" ]; # force overwrite
                    subvolumes = {
                      "@root" = {
                        mountpoint = "/";
                        mountOptions = [
                          "compress=zstd"
                          "noatime"
                        ];
                      };
                      "@persist" = {
                        mountpoint = "${config.hardware.host.persistFolder}";
                        mountOptions = [
                          "compress=zstd"
                          "noatime"
                        ];
                      };
                      "@nix" = {
                        mountpoint = "/nix";
                        mountOptions = [
                          "compress=zstd"
                          "noatime"
                        ];
                      };
                      "@swap" = lib.mkIf withSwap {
                        mountpoint = "/.swapvol";
                        swap.swapfile.size = "${swapSize}G";
                      };
                    };
                  };
                };
              };
            };
          };
        };
      };
    };

    # yubikey-manager removed - not required for password-only LUKS
    # Can be added manually if FIDO2 enrollment is desired post-install
  };
}
