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
                  mountpoint = config.host.persistFolder;
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
                    mountpoint = config.host.persistFolder;
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

  # Bcachefs layouts (import from separate files for modularity)
  bcachefsLayout = import ./bcachefs-disk.nix {
    disk = cfg.device;
  };

  bcachefsImpermanenceLayout = import ./bcachefs-impermanence-disk.nix {
    disk = cfg.device;
    persistFolder = config.host.persistFolder;
  };

  bcachefsLuksLayout = import ./bcachefs-luks-disk.nix {
    disk = cfg.device;
  };

  bcachefsLuksImpermanenceLayout = import ./bcachefs-luks-impermanence-disk.nix {
    disk = cfg.device;
    persistFolder = config.host.persistFolder;
  };

  # Select layout based on option
  selectedLayout =
    if cfg.layout == "btrfs" then
      btrfsLayout
    else if cfg.layout == "btrfs-impermanence" then
      btrfsImpermanenceLayout
    else if cfg.layout == "btrfs-luks-impermanence" then
      btrfsLuksImpermanenceLayout
    else if cfg.layout == "bcachefs" then
      bcachefsLayout.disko.devices.disk
    else if cfg.layout == "bcachefs-impermanence" then
      bcachefsImpermanenceLayout.disko.devices.disk
    else if cfg.layout == "bcachefs-luks" then
      bcachefsLuksLayout.disko.devices.disk
    else if cfg.layout == "bcachefs-luks-impermanence" then
      bcachefsLuksImpermanenceLayout.disko.devices
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
        "bcachefs"
        "bcachefs-impermanence"
        "bcachefs-luks"
        "bcachefs-luks-impermanence"
      ];
      default = "btrfs";
      description = ''
        Disk layout pattern to use:

        Btrfs layouts (subvolume-based):
        - btrfs: Simple btrfs with @root, @nix subvolumes
        - btrfs-impermanence: Adds @persist subvolume for impermanence
        - btrfs-luks-impermanence: LUKS encryption + impermanence

        Bcachefs layouts (partition-based, newer filesystem):
        - bcachefs: Simple bcachefs (single root partition)
        - bcachefs-impermanence: Separate /persist partition
        - bcachefs-luks: LUKS + bcachefs
        - bcachefs-luks-impermanence: LUKS + LVM + separate partitions

        Note: Bcachefs requires Linux 6.7+. LUKS provides compatibility
        with Phase 17 password management and key rotation workflows.
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
  };
}
