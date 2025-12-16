# YubiKey LUKS Enrollment Guide

**Last Updated**: 2025-12-16

This guide covers adding optional YubiKey FIDO2 unlock to LUKS-encrypted systems. YubiKey enrollment is **not required** - password-only unlock works perfectly. This is an enhancement for convenience and additional security layers.

## Overview

After migrating to LUKS encryption, you can optionally add YubiKey unlock:
- Touch YubiKey to unlock instead of typing password
- Password remains as fallback
- Multiple YubiKeys can be enrolled (backup keys)
- Can be removed at any time

## Prerequisites

### Hardware Requirements
- YubiKey 5 series or later with FIDO2 support
- USB port (or USB-C to USB-A adapter for newer systems)
- Working LUKS-encrypted system

### Software Requirements
```bash
# Check if yubikey-manager is installed
which ykman

# If not, add to your system configuration:
# environment.systemPackages = [ pkgs.yubikey-manager ];
# Or use temporarily:
nix-shell -p yubikey-manager
```

### System Requirements
- System must be fully booted and unlocked
- Root access required
- LUKS partition must be LUKS2 (default in NixOS)

## Enrollment Process

### Step 1: Identify LUKS Partition

```bash
# Find your LUKS partition
lsblk -f | grep crypto_LUKS

# Example output:
# nvme0n1p2  crypto_LUKS 2.6.1   encrypted-nixos   UUID="..."

# Usually:
# - /dev/nvme0n1p2 (NVMe SSD)
# - /dev/sda2 (SATA SSD/HDD)
# - /dev/vda2 (VM)
```

Note the device path (e.g., `/dev/nvme0n1p2`) - you'll need it.

### Step 2: Verify LUKS2 Format

```bash
# Check LUKS version
sudo cryptsetup luksDump /dev/nvme0n1p2 | grep Version

# Should output: Version:        2
# If Version 1, you need to convert (not covered here)
```

### Step 3: Enroll Primary YubiKey

```bash
# Insert YubiKey into USB port

# Enroll YubiKey for LUKS unlock
sudo systemd-cryptenroll --fido2-device=auto /dev/nvme0n1p2
```

**What happens**:
1. Prompts for current LUKS password
2. YubiKey will blink - touch the gold contact
3. Enrolls YubiKey credential
4. Creates LUKS2 token for automatic unlock

**Example output**:
```
A FIDO2 security token was found.
🔐 Please enter current passphrase for disk /dev/nvme0n1p2:
✨ Please touch your security token now...
[YubiKey blinks]
✓ New FIDO2 token enrolled as key slot 1.
```

### Step 4: Verify Enrollment

```bash
# Check LUKS tokens
sudo cryptsetup luksDump /dev/nvme0n1p2 | grep -A10 "Tokens:"

# Should show:
# Tokens:
#   0: systemd-fido2
#   Keyslot: 1
```

### Step 5: Test YubiKey Unlock

```bash
# Reboot to test
sudo reboot

# At LUKS prompt:
# 1. Insert YubiKey
# 2. YubiKey will blink - touch it
# 3. System should unlock automatically

# If it doesn't work, press ESC and enter password
```

## Enrolling Backup YubiKey

It's **highly recommended** to enroll a second YubiKey as backup.

```bash
# Insert second YubiKey
sudo systemd-cryptenroll --fido2-device=auto /dev/nvme0n1p2

# Follow same process:
# 1. Enter current password
# 2. Touch second YubiKey
# 3. Verify enrollment

# Check both are enrolled
sudo cryptsetup luksDump /dev/nvme0n1p2 | grep "Keyslot:"
# Should show multiple keyslots
```

**Important**: Store backup YubiKey in separate location (home safe, office, etc.)

## Configuration Options

### Option 1: Automatic Detection (Recommended)

Edit `/etc/crypttab` to automatically detect YubiKey:

```bash
# View current crypttab
cat /etc/crypttab

# Should contain line like:
# encrypted-nixos UUID=... none

# Add fido2-device option:
encrypted-nixos UUID=<uuid> none fido2-device=auto,token-timeout=10
```

Or configure in NixOS configuration:

```nix
{
  boot.initrd.luks.devices."encrypted-nixos" = {
    device = "/dev/disk/by-uuid/<uuid>";
    allowDiscards = true;
    crypttabExtraOpts = [
      "fido2-device=auto"
      "token-timeout=10"
    ];
  };
}
```

### Option 2: Manual Unlock

Without `fido2-device=auto`, you'll need to:
1. Wait for LUKS prompt
2. Insert YubiKey
3. Touch when it blinks
4. OR press ESC and enter password

### Option 3: Password-Only Fallback

YubiKey enrollment doesn't remove password unlock:
1. At LUKS prompt, press ESC
2. Enter your LUKS password
3. System unlocks without YubiKey

## Managing YubiKeys

### List All Enrolled Keys

```bash
# Show all keyslots
sudo cryptsetup luksDump /dev/nvme0n1p2

# Look for:
# Keyslot 0: luks2 (password)
# Keyslot 1: luks2 (fido2 - YubiKey 1)
# Keyslot 2: luks2 (fido2 - YubiKey 2)
```

### Remove YubiKey Enrollment

```bash
# List token IDs
sudo systemd-cryptenroll --fido2-device=list /dev/nvme0n1p2

# Remove specific token (replace N with slot number)
sudo systemd-cryptenroll --wipe-slot=N /dev/nvme0n1p2

# Example: Remove slot 1
sudo systemd-cryptenroll --wipe-slot=1 /dev/nvme0n1p2
```

### Change/Rotate YubiKey

```bash
# Remove old YubiKey
sudo systemd-cryptenroll --wipe-slot=1 /dev/nvme0n1p2

# Enroll new YubiKey
sudo systemd-cryptenroll --fido2-device=auto /dev/nvme0n1p2
```

## Multi-Factor Unlock Options

### Option A: YubiKey OR Password

**Default behavior** - either YubiKey or password works:
- Convenient: Touch YubiKey to unlock quickly
- Fallback: Enter password if YubiKey unavailable
- Security: Protects against cold boot attacks

**Setup**: Standard enrollment (covered above)

### Option B: YubiKey AND Password

**Higher security** - requires both YubiKey and password:
- More secure: Attacker needs both factors
- Less convenient: Must enter password + touch key
- Recovery: Harder to recover if one factor lost

**Setup**:
```bash
# Enroll with PIN requirement
sudo systemd-cryptenroll \
  --fido2-device=auto \
  --fido2-with-client-pin=yes \
  /dev/nvme0n1p2
```

### Option C: Multiple YubiKeys + Password

**Recommended setup** - 2 YubiKeys + password:
- Primary YubiKey for daily use
- Backup YubiKey in safe location
- Password as last resort
- Balance of security and convenience

**Setup**: Enroll primary + backup (covered above)

## Troubleshooting

### YubiKey Not Detected

**Symptoms**: System doesn't recognize YubiKey at boot

**Solutions**:
```bash
# 1. Check USB port (try different port)
# 2. Verify YubiKey works in OS:
ykman info

# 3. Check systemd version (needs 248+):
systemd --version

# 4. Verify FIDO2 is enabled on YubiKey:
ykman fido info

# 5. Re-enroll with explicit device:
sudo systemd-cryptenroll --fido2-device=/dev/hidraw0 /dev/nvme0n1p2
```

### YubiKey Blinks But Doesn't Unlock

**Symptoms**: Touch YubiKey but unlock fails

**Solutions**:
1. Touch gold contact firmly (full finger, not fingernail)
2. Hold touch for 1-2 seconds
3. Verify correct YubiKey enrolled (if you have multiple)
4. Check logs: `journalctl -b | grep systemd-cryptsetup`
5. Try ESC → password unlock
6. Re-enroll if needed

### Lost YubiKey

**Symptoms**: YubiKey lost or broken, need to access system

**Solutions**:
1. **Best**: Use backup YubiKey (if enrolled)
2. **Good**: Enter password (press ESC at prompt)
3. **Emergency**: Boot from USB, unlock manually, remove enrollment:
   ```bash
   cryptsetup luksOpen /dev/nvme0n1p2 encrypted-nixos
   # Enter password
   mount /dev/mapper/encrypted-nixos-root /mnt
   nixos-enter --root /mnt
   systemd-cryptenroll --wipe-slot=1 /dev/nvme0n1p2
   ```

### Enrollment Fails

**Symptoms**: `systemd-cryptenroll` returns error

**Common errors**:

1. **"No FIDO2 token found"**
   - Solution: Insert YubiKey, try again

2. **"Incorrect passphrase"**
   - Solution: Verify LUKS password is correct

3. **"LUKS2 required"**
   - Solution: Convert to LUKS2 or use password-only

4. **"Token slot already in use"**
   - Solution: Wipe existing slot first

## Security Considerations

### What YubiKey Adds

- **Physical presence**: Attacker needs physical YubiKey
- **Convenient unlock**: Touch instead of typing password
- **Brute-force protection**: Limited attempts before lockout
- **Tamper-evident**: Lost YubiKey is obvious

### What YubiKey Doesn't Add

- **No protection from running system**: Hot boot attacks still possible
- **No protection from evil maid**: Physical access while running
- **Not zero-knowledge**: Boot process could theoretically be compromised
- **USB vulnerabilities**: Potential for USB-based attacks

### Best Practices

1. **Enroll backup YubiKey**: Store in separate location
2. **Keep password strong**: YubiKey is convenience, not replacement
3. **Test fallback**: Regularly test password unlock works
4. **Physical security**: Don't leave YubiKey attached to laptop
5. **Separate YubiKeys**: Don't use same key for LUKS + other services
6. **Document enrollment**: Note which YubiKey is which
7. **Regular testing**: Test backup key quarterly

### Threat Model

**Good for**:
- Preventing laptop theft (device off)
- Protecting against casual attackers
- Convenience over password typing
- Physical presence requirement

**Not good for**:
- Nation-state adversaries
- Targeted evil maid attacks
- Protection while system running
- Zero-trust environments

## Recommendations

### For Laptops
- **Recommended**: Primary + backup YubiKey + password
- **Rationale**: Convenience for travel, backup if lost

### For Desktops
- **Recommended**: Password only (simpler)
- **Rationale**: Less risk of device theft, YubiKey adds complexity

### For Servers
- **Recommended**: Password only (required)
- **Rationale**: Servers need unattended reboot, YubiKey not practical

## Alternative: TPM Unlock

If your system has TPM 2.0, consider TPM-based unlock instead:

```bash
# Enroll TPM
sudo systemd-cryptenroll --tpm2-device=auto /dev/nvme0n1p2
```

**TPM advantages**:
- No external device needed
- Automatic unlock (no touch required)
- Tied to specific hardware

**TPM disadvantages**:
- Measured boot only (not implemented yet)
- Complex secure boot setup
- Less portable

See TPM documentation for details (future work).

## Summary

YubiKey enrollment is **optional** and adds:
- Convenience (touch vs typing)
- Physical presence requirement
- Protection against password shoulder-surfing

But keeps:
- Password fallback
- Recovery options
- Same security properties

**Most users**: Start with password-only, add YubiKey later if desired.

**Recommended setup**: Primary YubiKey + backup YubiKey + password fallback.

## Additional Resources

- [systemd-cryptenroll man page](https://www.freedesktop.org/software/systemd/man/systemd-cryptenroll.html)
- [YubiKey FIDO2 Guide](https://support.yubico.com/hc/en-us/articles/360016649059)
- [Arch Wiki: LUKS with FIDO2](https://wiki.archlinux.org/title/FIDO2)
- [YubiKey Manager CLI](https://developers.yubico.com/yubikey-manager/)
