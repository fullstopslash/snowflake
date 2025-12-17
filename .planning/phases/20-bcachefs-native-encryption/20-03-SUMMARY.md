# Phase 20 Plan 3: Boot Integration & Key Management Summary

**Implemented boot unlock automation and key management for bcachefs native encryption.**

## Accomplishments

- Created bcachefs-unlock.nix module for automatic boot unlock
- Integrated unlock module with disks module (automatic activation)
- Updated ISO installer with bcachefs encryption workflows
- Documented installation, boot, and recovery procedures
- Comprehensive encryption documentation in docs/bcachefs.md

## Files Created/Modified

- `modules/disks/bcachefs-unlock.nix` - Boot unlock automation module (new)
  - Detects bcachefs-encrypt layouts automatically
  - Enables systemd in initrd for robust unlock workflow
  - Configures kernel modules (bcachefs, sha256, poly1305, chacha20)
  - Provides warning messages with Clevis TPM setup instructions
  - Sets kernel to latest version for bcachefs improvements

- `modules/disks/default.nix` - Integrated unlock module (modified)
  - Added import for bcachefs-unlock.nix
  - Updated description with boot unlock documentation
  - Documents interactive passphrase prompt (default behavior)
  - Documents optional Clevis TPM/Tang automated unlock

- `docs/bcachefs.md` - Comprehensive encryption documentation (modified)
  - Added complete "Native Bcachefs Encryption (Declarative)" section
  - Documented installation workflow with Phase 17 password integration
  - Added boot unlock procedures (interactive and TPM)
  - Security advantages over LUKS (AEAD, tamper detection, replay protection)
  - Trade-offs and when to choose bcachefs-encrypt vs bcachefs-luks
  - Passphrase change procedures
  - Recovery scenarios (lost passphrase, TPM failure, corruption)
  - Updated layout descriptions with Phase 20 native encryption options
  - Enhanced comparison table with authenticated encryption row

- `nixos-installer/minimal-configuration.nix` - ISO already has bcachefs-tools (verified)
  - No changes needed, bcachefs-tools already included in ISO packages

## Decisions Made

### Unlock Mechanism: NixOS Built-in with Optional Clevis

Chose to leverage NixOS's existing bcachefs module rather than implementing custom unlock logic:

**Rationale:**
- NixOS bcachefs.nix module already handles unlock via systemd-ask-password
- Clevis integration built into nixpkgs for TPM/Tang automated unlock
- Fallback to interactive prompt automatically handled
- Kernel keyring management already implemented
- No need to duplicate existing, tested unlock infrastructure

**Implementation:**
- bcachefs-unlock.nix activates when layout contains "bcachefs-encrypt"
- Enables `boot.supportedFilesystems = [ "bcachefs" ]`
- Enables `boot.initrd.systemd.enable = true` for robust unlock
- Configures required kernel modules for ChaCha20/Poly1305
- Provides documentation via warnings on how to enable Clevis TPM unlock

### Interactive Passphrase as Default, Clevis as Optional

**Default behavior:** Interactive passphrase prompt via systemd-ask-password
- Works out-of-box with no additional configuration
- User enters passphrase at boot
- Reliable, simple, secure

**Optional TPM unlock:** Users can configure Clevis post-install
- Add boot.initrd.clevis configuration to host config
- Generate JWE token binding passphrase to TPM PCR 7
- Automatic unlock on boot, falls back to passphrase if TPM fails

### Documentation Approach

Comprehensive documentation covering:
1. Installation workflow (Phase 17 password integration)
2. Boot unlock (default interactive, optional TPM)
3. Security advantages (AEAD, tamper detection, replay protection)
4. Trade-offs vs LUKS (systemd-cryptenroll support, tooling maturity)
5. Passphrase management (format-time, boot-time, change procedures)
6. Recovery scenarios (lost passphrase, TPM failure, corruption)
7. When to choose native encryption vs LUKS

## Issues Encountered

None - implementation proceeded smoothly by leveraging existing NixOS bcachefs module infrastructure.

## Verification Results

All verification checks passed:
- ✅ bcachefs-unlock.nix module parses correctly
- ✅ bcachefs-unlock.nix imported in modules/disks/default.nix (2 occurrences)
- ✅ Documentation updated in default.nix (boot unlock section)
- ✅ bcachefs in supported filesystems for malphas config
- ✅ bcachefs-encrypt references in docs/bcachefs.md (multiple sections)
- ✅ bcachefs-tools available in ISO installer
- ✅ Module evaluation succeeds for all layout types

## Phase 20 Complete

**Phase 20: Bcachefs Native Encryption - Complete**

Summary: Successfully implemented bcachefs native ChaCha20/Poly1305 encryption with:
- Two new layout options (bcachefs-encrypt, bcachefs-encrypt-impermanence) - Plan 20-02
- Automatic boot unlock via NixOS built-in systemd infrastructure - Plan 20-03
- Optional Clevis TPM/Tang integration for automated unlock - Plan 20-03
- Phase 17 password infrastructure integration (/tmp/disko-password) - Plan 20-02, 20-03
- ISO installer support (bcachefs-tools already included) - Plan 20-03
- Comprehensive documentation in docs/bcachefs.md - Plan 20-03

Native encryption provides authenticated encryption chain with metadata integrity verification,
offering superior security properties compared to block-layer encryption. LUKS variants remain
available for environments requiring traditional full-disk encryption tooling (systemd-cryptenroll,
FIDO2/PKCS11/YubiKey support).

**Key Security Features:**
- AEAD (Authenticated Encryption with Associated Data)
- Per-block MAC with chain of trust to superblock
- Unique nonce for every encrypted block
- Tamper detection and replay attack protection
- Metadata integrity verification
- Superior to LUKS (unauthenticated encryption, no tamper detection)

**Performance Characteristics:**
- ChaCha20/Poly1305: ~400% faster than AES on systems without AES-NI
- Ideal for ARM/mobile devices
- Constant-time implementation resistant to timing attacks
- Lower power consumption than AES-GCM

**Unlock Workflow:**
1. Boot → initrd systemd detects encrypted bcachefs device
2. Default: Interactive passphrase prompt via systemd-ask-password
3. Optional: Clevis attempts TPM/Tang unlock, falls back to passphrase on failure
4. Passphrase unlocks device, key added to kernel keyring
5. Filesystem mounts and boot continues

**Migration Path:**
- Existing LUKS layouts (Phase 17) remain fully supported
- New installations can choose bcachefs-encrypt or bcachefs-luks based on requirements
- Clear documentation on trade-offs helps users make informed decisions
- No breaking changes to existing configurations

Next: Update ROADMAP.md to mark Phase 20 complete.
