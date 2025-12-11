# Disk configuration module
#
# Provides a simple interface for hosts to select disk layouts.
# Hosts just set options; the module handles disko configuration.
#
# Usage in host config:
#   disks = {
#     enable = true;
#     layout = "btrfs";  # or "btrfs-impermanence", "btrfs-luks-impermanence"
#     device = "/dev/vda";
#     withSwap = true;
#     swapSize = "8";
#   };
#
# For host-specific disk configs (like ghost.nix), set disks.enable = false
# and import the custom config from modules/disks/hosts/
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.disks;

  # Common btrfs mount options
  btrfsMountOpts = [
    "compress=zstd"
    "noatime"
  ];

  # Common ESP partition
  espPartition = {
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

  # Swap subvolume (conditional)
  swapSubvolume = lib.mkIf cfg.withSwap {
    mountpoint = "/.swapvol";
    swap.swapfile.size = "${cfg.swapSize}G";
  };

  # Layout: Simple btrfs (no encryption, no impermanence)
  btrfsLayout = {
    disk0 = {
      type = "disk";
      device = cfg.device;
      content = {
        type = "gpt";
        partitions = {
          ESP = espPartition;
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "@root" = {
                  mountpoint = "/";
                  mountOptions = btrfsMountOpts;
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = btrfsMountOpts;
                };
                "@swap" = swapSubvolume;
              };
            };
          };
        };
      };
    };
  };

  # Layout: btrfs with impermanence (persist subvolume, no encryption)
  btrfsImpermanenceLayout = {
    disk0 = {
      type = "disk";
      device = cfg.device;
      content = {
        type = "gpt";
        partitions = {
          ESP = espPartition;
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "@root" = {
                  mountpoint = "/";
                  mountOptions = btrfsMountOpts;
                };
                "@persist" = {
                  mountpoint = config.hostSpec.persistFolder;
                  mountOptions = btrfsMountOpts;
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = btrfsMountOpts;
                };
                "@swap" = swapSubvolume;
              };
            };
          };
        };
      };
    };
  };

  # Layout: btrfs with LUKS encryption and impermanence
  btrfsLuksImpermanenceLayout = {
    disk0 = {
      type = "disk";
      device = cfg.device;
      content = {
        type = "gpt";
        partitions = {
          ESP = espPartition;
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "encrypted-nixos";
              passwordFile = "/tmp/disko-password";
              settings = {
                allowDiscards = true;
                crypttabExtraOpts = [
                  "fido2-device=auto"
                  "token-timeout=10"
                ];
              };
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "@root" = {
                    mountpoint = "/";
                    mountOptions = btrfsMountOpts;
                  };
                  "@persist" = {
                    mountpoint = config.hostSpec.persistFolder;
                    mountOptions = btrfsMountOpts;
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = btrfsMountOpts;
                  };
                  "@swap" = swapSubvolume;
                };
              };
            };
          };
        };
      };
    };
  };

  # Select layout based on option
  selectedLayout =
    if cfg.layout == "btrfs" then
      btrfsLayout
    else if cfg.layout == "btrfs-impermanence" then
      btrfsImpermanenceLayout
    else
      btrfsLuksImpermanenceLayout;
in
{
  options.disks = {
    enable = lib.mkEnableOption "disk configuration via disko";

    layout = lib.mkOption {
      type = lib.types.enum [
        "btrfs"
        "btrfs-impermanence"
        "btrfs-luks-impermanence"
      ];
      default = "btrfs";
      description = ''
        Disk layout pattern to use:
        - btrfs: Simple btrfs with @root, @nix subvolumes
        - btrfs-impermanence: Adds @persist subvolume for impermanence
        - btrfs-luks-impermanence: LUKS encryption + impermanence
      '';
    };

    device = lib.mkOption {
      type = lib.types.str;
      default = "/dev/vda";
      description = "Primary disk device path";
    };

    withSwap = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to create a swap file";
    };

    swapSize = lib.mkOption {
      type = lib.types.str;
      default = "8";
      description = "Swap size in GB (only used if withSwap is true)";
    };
  };

  # Always import disko module so the options are available
  imports = [ inputs.disko.nixosModules.disko ];

  config = lib.mkIf cfg.enable {
    disko.devices.disk = selectedLayout;

    # Add yubikey-manager for LUKS layouts (needed for fido2 enrollment)
    environment.systemPackages = lib.mkIf (cfg.layout == "btrfs-luks-impermanence") [
      pkgs.yubikey-manager
    ];
  };
}
