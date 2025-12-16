# Host Disk Configuration Audit

**Date**: 2025-12-16
**Phase**: 17-01 Physical Security & Recovery

## Overview

This document catalogs all hosts in the nix-config and their current disk encryption status.

## Host Inventory

### VMs (Not Requiring LUKS)

#### 1. griefling
- **Role**: Test VM (Desktop environment testing)
- **Disk Layout**: `btrfs` (unencrypted)
- **Device**: `/dev/vda`
- **Swap**: No
- **Status**: VM - LUKS not required
- **Notes**: Used for testing desktop features and GUI applications

#### 2. malphas
- **Role**: Primary Development VM
- **Disk Layout**: `btrfs` (unencrypted)
- **Device**: `/dev/vda`
- **Swap**: No
- **Status**: VM - LUKS not required
- **Notes**: Currently running as VM, includes audio tuning configuration

#### 3. sorrow
- **Role**: Headless GitOps Test VM
- **Disk Layout**: `btrfs` (unencrypted)
- **Device**: `/dev/vda`
- **Swap**: No
- **Status**: VM - LUKS not required
- **Notes**: Fast-deploying headless VM for testing auto-upgrade workflows

#### 4. torment
- **Role**: Headless GitOps Test VM
- **Disk Layout**: `btrfs` (unencrypted)
- **Device**: `/dev/vda`
- **Swap**: No
- **Status**: VM - LUKS not required
- **Notes**: Paired with sorrow for multi-host testing

#### 5. misery (TEST HOST)
- **Role**: Physical Security Testing VM
- **Disk Layout**: `btrfs-luks-impermanence` (ENCRYPTED)
- **Device**: `/dev/vda`
- **Swap**: Yes (4GB)
- **Status**: **LUKS ENABLED** - Testing configuration
- **Notes**:
  - Specifically created for Phase 17 testing
  - Already configured with LUKS encryption
  - Uses password-only unlock (no YubiKey)
  - Tests impermanence + LUKS combination
  - Marked as non-production (isProduction = false)

### ISO Installer

#### iso
- **Role**: Installation media
- **Disk Layout**: N/A (live system)
- **Status**: Special case - not a persistent installation

## Physical Hosts (Future LUKS Migration)

**None currently identified in this configuration.**

All active hosts are VMs. If physical hosts exist:
- They would need to be added to the `hosts/` directory
- Migration would follow procedures in `docs/luks-migration.md`
- Priority would be: Test on non-critical → Desktops → Laptops → Production servers

## Disk Layout Summary

| Host | Type | Layout | Encrypted | Swap | Purpose |
|------|------|--------|-----------|------|---------|
| griefling | VM | btrfs | No | No | Desktop Test |
| malphas | VM | btrfs | No | No | Development |
| sorrow | VM | btrfs | No | No | GitOps Test |
| torment | VM | btrfs | No | No | GitOps Test |
| **misery** | **VM** | **btrfs-luks-impermanence** | **Yes** | **Yes (4GB)** | **LUKS Testing** |
| iso | ISO | N/A | N/A | N/A | Installer |

## LUKS Configuration Status

### Current Implementation

The nix-config supports LUKS encryption through two mechanisms:

1. **New Module System** (`modules/disks/default.nix`):
   - Clean, integrated disk configuration
   - Three layouts: `btrfs`, `btrfs-impermanence`, `btrfs-luks-impermanence`
   - **Password-only unlock by default**
   - No FIDO2/YubiKey requirement
   - Used by hosts via `disks.layout` option

2. **Legacy Installer Files** (`modules/disks/btrfs-luks-impermanence-disk.nix`):
   - Used by `nixos-installer/flake.nix` for bootstrap process
   - **Updated to remove FIDO2 requirement** (Phase 17-01)
   - Password set via `/tmp/disko-password` during bootstrap
   - YubiKey enrollment available post-install (optional)

### Password Handling

- Bootstrap script (`scripts/bootstrap-nixos.sh`) prompts for LUKS passphrase
- Default test passphrase: "passphrase" (should be changed post-install)
- Password file: `/tmp/disko-password` (temporary, used by disko)
- Production: User prompted or sets via `--luks-passphrase` option

### YubiKey Status

- **NOT REQUIRED** for initial setup or boot
- Can be enrolled **post-installation** using:
  ```bash
  sudo systemd-cryptenroll --fido2-device=auto /dev/device
  ```
- Multiple YubiKeys can be enrolled
- Password remains as fallback even with YubiKey

## Migration Priority

Since all current hosts are VMs:

1. **Completed**: misery VM (already has LUKS)
2. **Not Applicable**: Other VMs (griefling, malphas, sorrow, torment)
3. **Future**: Physical hosts when added to configuration

## Security Properties

### With LUKS Encryption (misery):
- Cold boot attack prevented (disk encrypted when powered off)
- Age keys encrypted at rest
- Physical theft of powered-off device = secrets protected
- Impermanence ensures clean slate on reboot
- Password-only unlock (no hardware token required)

### Without LUKS (other VMs):
- Age keys stored unencrypted at `/var/lib/sops-nix/key.txt` (mode 600)
- Physical device theft = full secret compromise
- Suitable for VMs since hypervisor provides isolation
- Physical host security depends on hypervisor

## Recommendations

1. **Keep VMs unencrypted** - Hypervisor provides sufficient isolation
2. **Encrypt physical hosts** - Use LUKS for any laptop, desktop, or server
3. **Test on misery first** - Validate all procedures on test VM before production
4. **Document passphrases** - Store LUKS passphrases in password manager
5. **Glass-key recovery** - Ensure passphrase backup for disaster recovery

## Next Steps

1. Validate LUKS works on misery (test boot, secrets decryption)
2. Document migration procedures for future physical hosts
3. Create per-host migration plans when physical hosts added
4. Optional: Document YubiKey enrollment for enhanced security
