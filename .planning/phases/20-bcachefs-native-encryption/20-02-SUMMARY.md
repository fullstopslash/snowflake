# Phase 20 Plan 2: Native Encryption Layouts Summary

**Implemented bcachefs native ChaCha20/Poly1305 encryption layouts with authenticated encryption chain.**

## Accomplishments

- Created `bcachefs-encrypt-disk.nix` - Simple native encryption layout
- Created `bcachefs-encrypt-impermanence-disk.nix` - Encrypted impermanence layout
- Updated `modules/disks/default.nix` with new layout options
- Documented native encryption vs LUKS trade-offs
- All verification tests pass

## Files Created/Modified

- `modules/disks/bcachefs-encrypt-disk.nix` - Simple native encryption layout (68 lines)
  - ESP partition (512M, vfat)
  - Encrypted bcachefs root (100%, ChaCha20/Poly1305)
  - Uses `extraFormatArgs = ["--encrypted"]` for native encryption
  - Password from `/tmp/disko-password` (Phase 17 compatibility)
  - LZ4 compression for performance

- `modules/disks/bcachefs-encrypt-impermanence-disk.nix` - Encrypted impermanence layout (93 lines)
  - ESP partition (512M, vfat)
  - Encrypted bcachefs persist partition (50%, for persistent data)
  - Encrypted bcachefs root partition (50%, ephemeral)
  - Both partitions independently encrypted
  - Separate partitions approach (bcachefs doesn't use subvolumes for impermanence)

- `modules/disks/default.nix` - Added new layout options
  - Added `bcachefs-encrypt` to enum
  - Added `bcachefs-encrypt-impermanence` to enum
  - Updated description with native encryption documentation
  - Added import statements for new layouts
  - Added conditional routing in `selectedLayout`

## Decisions Made

### Encryption Configuration Pattern
- Used `extraFormatArgs = ["--encrypted"]` to enable native encryption during format
- Used `passwordFile = "/tmp/disko-password"` for Phase 17 password management compatibility
- Used LZ4 compression (balanced performance) instead of zstd (used in non-encrypted layouts)
- Background compression enabled for both layouts

### Impermanence Pattern
- Chose **separate encrypted partitions** approach (50% persist, 50% root)
- Each partition independently encrypted with same password during format
- Avoids bcachefs subvolume approach mentioned in FINDINGS (not suitable for impermanence reset pattern)
- Persistent and ephemeral data physically separated at partition level

### Documentation Emphasis
- Clear comments explaining AEAD encryption advantages (tamper detection, replay protection)
- Documented trade-offs: no systemd-cryptenroll support vs superior security
- Guidance on when to use native encryption vs LUKS
- Performance notes: better on ARM/mobile without AES-NI

## Issues Encountered

None - implementation proceeded smoothly following FINDINGS recommendations.

## Verification Results

All verification checks passed:
- ✅ Both new layout files exist and follow disko structure
- ✅ Import test succeeds for bcachefs-encrypt-disk.nix (shows "bcachefs" format)
- ✅ Import test succeeds for bcachefs-encrypt-impermanence-disk.nix (both partitions show "bcachefs")
- ✅ modules/disks/default.nix enum includes new options (bcachefs-encrypt, bcachefs-encrypt-impermanence)
- ✅ selectedLayout properly routes to new layouts
- ✅ Module evaluation succeeds without errors (tested with griefling config)
- ✅ Comments explain native encryption benefits vs LUKS

## Next Step

Ready for **20-03-PLAN.md** (boot integration and key management):
- Implement systemd units for bcachefs unlock during boot
- Integrate with Phase 17 password prompt infrastructure
- Add Clevis support for TPM-based automated unlock (optional)
- Update ISO installer to support bcachefs encryption workflows
- Test boot unlock on physical hardware

## Technical Notes

### Disko Configuration Pattern Used

Based on FINDINGS.md recommendations:
- `type = "filesystem"` with `format = "bcachefs"`
- `extraFormatArgs = ["--encrypted", "--compression=lz4", "--background_compression=lz4"]`
- `passwordFile = "/tmp/disko-password"` for bootstrap integration
- `mountOptions = ["compression=lz4", "noatime"]` for runtime behavior

### Why Separate Partitions for Impermanence

While bcachefs supports subvolumes (mentioned in FINDINGS), the impermanence pattern requires:
1. Root filesystem that can be wiped/reset
2. Persistent data that survives resets

Separate partitions provide clean separation:
- Root partition: Can be reformatted or reset without affecting persist
- Persist partition: Isolated from ephemeral root, survives complete root resets
- Both encrypted independently for security

This differs from btrfs subvolume approach where @root and @persist share the same filesystem.

### Phase 17 Compatibility

Both layouts maintain compatibility with Phase 17 infrastructure:
- Use `/tmp/disko-password` for format-time encryption
- Password prompt flow unchanged from LUKS layouts
- Same bootstrap workflow (user enters password once during install)
- Post-install unlock automation TBD in Phase 20-03

### Security Properties

ChaCha20/Poly1305 AEAD provides:
- **Confidentiality**: Data encrypted with ChaCha20 stream cipher
- **Authenticity**: Poly1305 MAC verifies data integrity
- **Nonce uniqueness**: Every encrypted block has unique nonce
- **Chain of trust**: MACs linked from superblock through all metadata
- **Tamper detection**: Modification of encrypted blocks detectable
- **Replay protection**: Cannot replay old encrypted blocks

This exceeds LUKS security model which provides confidentiality only (no authentication).
