# Bcachefs Filesystem Guide

Bcachefs is a modern, high-performance filesystem for Linux with native support for copy-on-write, compression, encryption, snapshots, and multi-device configurations. This guide covers using bcachefs with your nix-config.

## Quick Start

To use bcachefs on a new host, set the disk layout in your host configuration:

```nix
{
  disks = {
    enable = true;
    layout = "bcachefs";  # or bcachefs-luks, bcachefs-impermanence, etc.
    device = "/dev/nvme0n1";
    withSwap = true;
    swapSize = "16";  # GB
  };
}
```

## Available Layouts

### Simple Layouts

#### `bcachefs`
Single bcachefs partition with no encryption or impermanence.

**Use case:** Simple desktop or server without encryption requirements

**Structure:**
```
/dev/sda
├─ EFI System Partition (512M, vfat)
└─ bcachefs partition (remaining space)
   └─ / (root filesystem)
```

#### `bcachefs-impermanence`
Two separate bcachefs partitions for impermanence pattern.

**Use case:** Ephemeral root with persistent data storage

**Structure:**
```
/dev/sda
├─ EFI System Partition (512M, vfat)
├─ bcachefs partition (50% of disk)
│  └─ /persist (persistent data)
└─ bcachefs partition (remaining 50%)
   └─ / (root filesystem, wiped on reboot)
```

**Note:** Unlike btrfs which uses subvolumes, bcachefs uses separate partitions for impermanence because it doesn't have subvolume support.

### Encrypted Layouts

#### `bcachefs-encrypt` (Phase 20)
Native ChaCha20/Poly1305 authenticated encryption.

**Use case:** Encrypted laptop with superior security properties (tamper detection, replay protection)

**Structure:**
```
/dev/sda
├─ EFI System Partition (512M, vfat)
└─ Encrypted bcachefs partition
   └─ / (root filesystem, AEAD encrypted)
```

**Advantages:**
- Authenticated encryption (detect tampering)
- Filesystem-native encryption integration
- Better performance on ARM/mobile devices
- TPM unlock via Clevis with passphrase fallback

**Trade-offs:**
- No systemd-cryptenroll support (use Clevis for TPM)
- Newer encryption approach (less tooling ecosystem)

#### `bcachefs-encrypt-impermanence` (Phase 20)
Native encryption + separate partitions for impermanence.

**Use case:** Encrypted ephemeral system with authenticated encryption

**Structure:**
```
/dev/sda
├─ EFI System Partition (512M, vfat)
├─ Encrypted bcachefs partition (50%)
│  └─ /persist (persistent data, AEAD encrypted)
└─ Encrypted bcachefs partition (50%)
   └─ / (root filesystem, AEAD encrypted, wiped on reboot)
```

**Why separate partitions?** Each independently encrypted, root can be wiped without affecting persist.

#### `bcachefs-luks`
LUKS-encrypted bcachefs partition.

**Use case:** Encrypted laptop requiring FIDO2/YubiKey support

**Structure:**
```
/dev/sda
├─ EFI System Partition (512M, vfat)
└─ LUKS container
   └─ bcachefs filesystem
      └─ / (root filesystem)
```

**Benefits of LUKS:**
- Compatible with existing Phase 17 LUKS infrastructure
- systemd-cryptenroll support (FIDO2, YubiKey, PKCS11)
- Password management and key rotation workflows established
- Boot integration well-supported in NixOS

#### `bcachefs-luks-impermanence`
LUKS + LVM + separate bcachefs partitions for impermanence.

**Use case:** Encrypted system with ephemeral root and mature encryption tooling

**Structure:**
```
/dev/sda
├─ EFI System Partition (512M, vfat)
└─ LUKS container
   └─ LVM Physical Volume
      ├─ LV: persist (50% of space)
      │  └─ bcachefs filesystem → /persist
      └─ LV: root (remaining space)
         └─ bcachefs filesystem → /
```

**Why LVM?** Allows flexible partition sizing within encrypted container without exposing partition boundaries.

## Bcachefs vs Btrfs

| Feature | Bcachefs | Btrfs |
|---------|----------|-------|
| Compression | ✅ zstd, lz4, gzip, zlib | ✅ zstd, lzo, zlib |
| Snapshots | ✅ Native | ✅ Native |
| Subvolumes | ❌ Use partitions instead | ✅ Yes |
| Native encryption | ✅ ChaCha20/Poly1305 AEAD | ❌ Use LUKS |
| Multi-device | ✅ RAID 0/1/5/6/10 | ✅ RAID 0/1/10 |
| Maturity | ⚠️ Newer (mainline 6.7+) | ✅ Stable since 2013 |
| Performance | ⚡ Very fast | 🚀 Fast |
| Checksums | ✅ CRC32C + CRC64 | ✅ CRC32C, xxHash, SHA256 |
| Authenticated encryption | ✅ Tamper detection built-in | ❌ Requires dm-verity |

## Mount Options

The default bcachefs mount options used in all layouts:

```nix
bcachefsMountOpts = [
  "compression=zstd"  # Transparent compression (saves space)
  "noatime"           # Don't update access times (better performance)
];
```

### Additional Options You Can Add

Modify your host config to override mount options:

```nix
{
  fileSystems."/" = {
    options = [
      "compression=zstd"
      "noatime"
      "background_compression"  # Compress existing data in background
      "foreground_target=metadata"  # Prioritize metadata for SSD
    ];
  };
}
```

See [Bcachefs mount options](https://bcachefs.org/Manpage/) for full list.

## Encryption

### Native Bcachefs Encryption (Declarative)

**Available since Phase 20!** Use `bcachefs-encrypt` or `bcachefs-encrypt-impermanence` layouts for native ChaCha20/Poly1305 authenticated encryption.

#### Quick Start

```nix
{
  disks = {
    enable = true;
    layout = "bcachefs-encrypt";  # or bcachefs-encrypt-impermanence
    device = "/dev/nvme0n1";
  };
}
```

#### Installation Workflow

1. **During installation**, you'll be prompted for a passphrase (Phase 17 password infrastructure):
   ```bash
   # The installer will prompt and store in /tmp/disko-password
   # Disko uses this to format the encrypted bcachefs partition
   ```

2. **At boot**, unlock via interactive passphrase prompt (default):
   ```
   # systemd-ask-password prompts for passphrase
   # Enter the same passphrase from installation
   # System unlocks and continues boot
   ```

3. **Optional: Enable TPM automated unlock** (post-install):
   ```nix
   {
     boot.initrd.clevis = {
       enable = true;
       devices."root".secretFile = "/persist/etc/clevis/root.jwe";
     };
   }
   ```

   Generate Clevis JWE token:
   ```bash
   # Boot system once with passphrase
   # Generate TPM-bound token (PCR 7 for secure boot):
   echo "your-passphrase" | clevis encrypt tpm2 '{"pcr_ids":"7"}' > /persist/etc/clevis/root.jwe

   # Rebuild system to include token in initrd
   sudo nixos-rebuild boot

   # Future boots will auto-unlock via TPM, fallback to passphrase if TPM fails
   ```

#### Security Advantages over LUKS

Native bcachefs encryption uses AEAD (Authenticated Encryption with Associated Data):

- **Tamper detection**: Each encrypted block has a Poly1305 MAC
- **Replay protection**: Unique nonce per block with chain of trust to superblock
- **Metadata integrity**: Encryption and checksums integrated (no separate dm-crypt layer)
- **Better performance on ARM/mobile**: ChaCha20 ~400% faster than AES without AES-NI hardware

LUKS provides only confidentiality (unauthenticated encryption), cannot detect tampering.

#### Trade-offs vs LUKS

**Choose bcachefs-encrypt when:**
- Need authenticated encryption (tamper detection)
- Working with ARM/mobile devices
- Want filesystem-native encryption integration
- TPM unlock via Clevis is acceptable

**Choose bcachefs-luks when:**
- Need FIDO2/PKCS11/YubiKey support (systemd-cryptenroll)
- Want mature encryption tooling ecosystem
- Require compatibility with traditional backup tools
- Enterprise compliance mandates LUKS

#### Changing Passphrase

Post-install passphrase change:
```bash
# Unmount filesystem first (boot from live media or use separate partition)
sudo bcachefs set-passphrase /dev/nvme0n1p2

# Or for mounted filesystem (if supported by current kernel):
sudo bcachefs set-passphrase /
```

#### Recovery Scenarios

**Lost passphrase:**
- No recovery possible (by design)
- Encrypted data is permanently inaccessible
- Backups are essential

**TPM failure (with Clevis configured):**
- System automatically falls back to passphrase prompt
- Enter passphrase manually to unlock
- Boot proceeds normally

**Corrupted encryption:**
```bash
# Boot from live media
bcachefs fsck --degraded /dev/nvme0n1p2

# Check encryption status
bcachefs unlock -c /dev/nvme0n1p2
```

### LUKS Encryption (Alternative)

**Use the `bcachefs-luks` or `bcachefs-luks-impermanence` layouts** for traditional LUKS block-layer encryption:
- Phase 17 password management integration
- Key rotation workflows (`just rekey`)
- YubiKey/FIDO2 post-install enrollment (systemd-cryptenroll)
- Disaster recovery procedures

See [docs/luks-migration.md](luks-migration.md) for LUKS setup details.

## Multi-Device Configurations

Bcachefs supports RAID across multiple devices. This requires custom disko configuration:

```nix
{
  disko.devices = {
    disk = {
      ssd1 = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            bcachefs = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "bcachefs";
                mountpoint = "/";
                extraArgs = [
                  "--replicas=2"  # RAID1 across devices
                  "/dev/nvme0n1p1"
                  "/dev/nvme1n1p1"
                ];
              };
            };
          };
        };
      };
      ssd2 = {
        type = "disk";
        device = "/dev/nvme1n1";
        # Similar configuration
      };
    };
  };
}
```

## Maintenance

### Check Filesystem Health

```bash
# Check filesystem (unmounted)
bcachefs fsck /dev/sda2

# Check online filesystem
bcachefs fs usage /

# View detailed stats
bcachefs show-super /dev/sda2
```

### Enable Background Compression

Compress existing data in the background:

```bash
bcachefs set-option compression=zstd /dev/sda2
mount -o remount,background_compression /
```

### Snapshots

Create read-only snapshots:

```bash
bcachefs snapshot / /.snapshots/$(date +%Y%m%d)
```

Note: Snapshot support in bcachefs is still evolving. Check [Bcachefs documentation](https://bcachefs.org/) for current status.

## Kernel Requirements

- **Minimum:** Linux 6.7 (bcachefs merged into mainline)
- **Recommended:** Linux 6.11+ (stability improvements)
- **Your config:** ISO includes bcachefs-tools by default

Check your kernel version:
```bash
uname -r
```

If running older kernel, update in your configuration:
```nix
{
  boot.kernelPackages = pkgs.linuxPackages_latest;
}
```

## Troubleshooting

### "Unknown filesystem type 'bcachefs'"

Your kernel doesn't have bcachefs support. Update to Linux 6.7+:
```nix
boot.kernelPackages = pkgs.linuxPackages_latest;
```

### Slow Performance

Try different mount options:
```nix
fileSystems."/" = {
  options = [
    "compression=lz4"  # Faster than zstd
    "noatime"
    "foreground_target=metadata"
  ];
};
```

### Encryption Issues

If using native bcachefs encryption, ensure unlock happens before mount:
- Boot logs: `journalctl -b`
- Check initrd services: `systemctl list-units --type=service`

For LUKS encryption (recommended), see Phase 17 troubleshooting in [docs/luks-migration.md](luks-migration.md).

## Migration from Btrfs

To migrate an existing btrfs system to bcachefs:

1. **Backup all data** - This is a full reinstall
2. Update host config to use bcachefs layout
3. Reinstall using `just install <hostname> <ip>` or `install-host <hostname>` from ISO
4. Restore data from backup to /persist

There is no in-place conversion tool from btrfs → bcachefs.

## Further Reading

- [Bcachefs official documentation](https://bcachefs.org/)
- [Bcachefs principles of operation (PDF)](https://bcachefs.org/bcachefs-principles-of-operation.pdf)
- [NixOS Wiki: Bcachefs](https://wiki.nixos.org/wiki/Bcachefs)
- [Disko bcachefs examples](https://github.com/nix-community/disko/blob/master/example/bcachefs.nix)
- [Bcachefs encryption guide](https://bcachefs.org/Encryption/)

## Example Host Configurations

### Simple Desktop

```nix
# hosts/desktop/default.nix
{
  imports = [ ./hardware-configuration.nix ];

  roles = [ "desktop" ];

  host = {
    hostName = "desktop";
    primaryUsername = "rain";
  };

  disks = {
    enable = true;
    layout = "bcachefs";
    device = "/dev/nvme0n1";
    withSwap = true;
    swapSize = "16";
  };
}
```

### Encrypted Laptop with Impermanence

```nix
# hosts/laptop/default.nix
{
  imports = [ ./hardware-configuration.nix ];

  roles = [ "laptop" ];

  host = {
    hostName = "laptop";
    primaryUsername = "rain";
    persistFolder = "/persist";
  };

  disks = {
    enable = true;
    layout = "bcachefs-luks-impermanence";
    device = "/dev/nvme0n1";
    withSwap = true;
    swapSize = "8";
  };

  # Enable impermanence module
  system.impermanence.enable = true;
}
```

### Test VM

```nix
# hosts/test-bcachefs/default.nix
{
  imports = [ ./hardware-configuration.nix ];

  roles = [ "vm" "test" ];

  host = {
    hostName = "test-bcachefs";
    primaryUsername = "rain";
    isProduction = false;
  };

  disks = {
    enable = true;
    layout = "bcachefs";  # Simple layout for testing
    device = "/dev/vda";
  };
}
```
