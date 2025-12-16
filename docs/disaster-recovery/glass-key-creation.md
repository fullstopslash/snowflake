# Glass-Key Physical Backup Creation

## Overview

Glass-key backups are physical, offline copies of your master recovery key and configuration repositories. They enable complete infrastructure rebuild from catastrophic loss scenarios (fire, flood, theft, account lockout).

**Glass-Key Principle**: "If I only have what's in my fireproof safe, can I rebuild everything?" Answer must be YES.

## Backup Formats

Create backups in multiple formats for redundancy and different recovery scenarios:

1. **Paper** - Fast creation, easy reading, quarterly updates
2. **Metal** - Long-term durability, fire/water resistant, infrequent updates
3. **USB** - Complete backup with git repos, encrypted, quarterly updates
4. **QR Code** - Phone-scannable, eliminates typing errors, printed with paper

## 1. Paper Backup (Primary)

### Materials Needed

- Laser printer (inkjet fades over time)
- High-quality paper (acid-free archival paper recommended)
- Laminating pouches and laminator
- Fireproof safe or document bag

### Creation Process

Create a document with the following format:

```
═══════════════════════════════════════════════════════════════
                 MASTER AGE KEY - DISASTER RECOVERY
                      CREATED: 2025-12-16
═══════════════════════════════════════════════════════════════

PRIVATE KEY:
AGE-SECRET-KEY-1[rest-of-private-key-exactly-as-generated]

PUBLIC KEY:
age1[public-key-exactly-as-shown]

═══════════════════════════════════════════════════════════════
                      RECOVERY INSTRUCTIONS
═══════════════════════════════════════════════════════════════

SCENARIO: Total infrastructure loss (all devices destroyed/stolen)

REQUIREMENTS:
- This paper
- Internet connection
- Any computer (can install NixOS)
- USB drive (if using offline bundles)

STEPS:

1. Install NixOS on new machine
   - Download NixOS ISO: https://nixos.org/download.html
   - Boot from USB, connect to network
   - Install minimal system with networking

2. Install required tools
   nix-shell -p git age sops

3. Restore repositories
   # Option A: From GitHub (if accessible)
   git clone https://github.com/[your-username]/nix-config
   git clone https://github.com/[your-username]/nix-secrets

   # Option B: From USB backup bundle (no network needed)
   git clone /mnt/usb/nix-config.bundle nix-config
   git clone /mnt/usb/nix-secrets.bundle nix-secrets

4. Save this master key
   # Type the private key from this paper:
   cat > ~/master-recovery-key.txt << 'EOF'
   [paste private key here]
   EOF
   chmod 600 ~/master-recovery-key.txt

5. Test decryption
   export SOPS_AGE_KEY_FILE=~/master-recovery-key.txt
   sops -d nix-secrets/sops/shared.yaml
   # Should show decrypted secrets

6. Bootstrap first host
   cd nix-config
   sudo SOPS_AGE_KEY_FILE=$SOPS_AGE_KEY_FILE \
     ./scripts/bootstrap-nixos.sh -n [hostname] -d /dev/sda

7. Follow detailed recovery guide
   See: nix-config/docs/disaster-recovery/total-recovery.md

═══════════════════════════════════════════════════════════════
                         STORAGE NOTES
═══════════════════════════════════════════════════════════════

COPY: 1 of 3
LOCATION: [Document location offline, not on this paper]
LAST UPDATED: 2025-12-16
NEXT REVIEW: 2026-12-16

WARNING: This key can decrypt ALL secrets in the infrastructure.
         Store in fireproof safe. Never photograph or digitize.
         Never store all copies in same physical location.

═══════════════════════════════════════════════════════════════
```

### Printing Instructions

1. **Font**: Monospace (Courier New, 10pt) for keys to preserve spacing
2. **Print**: Use laser printer (toner doesn't fade like ink)
3. **Verify**: After printing, manually verify key characters match
4. **Count**: Print at least 3 copies
5. **Label**: Mark each as "Copy 1 of 3", "Copy 2 of 3", etc.

### Lamination

```bash
# After printing
1. Place each page in laminating pouch
2. Run through laminator at appropriate heat setting
3. Trim excess lamination, leave 1/4 inch border
4. Test durability (should survive water immersion)
```

**Why laminate?**
- Water resistance (flood, sprinkler, coffee spill)
- Prevents paper degradation
- Protects from handling wear
- Increases longevity

### Storage Locations

**Minimum 3 copies in different locations:**

1. **Home Safe** (Copy 1)
   - Fireproof safe (rated for paper protection)
   - Quick access for recovery
   - Protected from casual theft

2. **Off-Site Secure** (Copy 2)
   - Safety deposit box (bank)
   - Trusted family member's safe
   - Off-site business location
   - Protection from home disaster (fire/flood)

3. **Emergency Backup** (Copy 3)
   - Sealed envelope with trusted friend/family
   - Label: "Emergency recovery key - open only if I request"
   - Different geographic location if possible

**NEVER store:**
- All copies in same location
- In easily accessible drawer
- Without fire protection
- Photographed on phone
- Scanned to computer/cloud

## 2. Metal Backup (Long-Term)

### Materials Needed

- Stainless steel plate (304 or 316 grade, 4" x 6" minimum)
- Metal stamps or engraving tool
- Center punch (for marking before stamping)
- Safety glasses
- Vise or clamp

### Why Metal?

- **Fire resistant**: Survives house fires (stainless steel melting point: 2500°F)
- **Water proof**: Corrosion resistant, survives floods
- **Longevity**: Decades without degradation
- **Durability**: Cannot tear, burn, or fade

### Creation Process

```bash
# Only stamp the PRIVATE key - public key can be derived from private
# Format for metal backup (conserve space):

MASTER AGE KEY
[Date]
AGE-SECRET-KEY-1[private-key]
```

**Stamping Instructions:**

1. **Plan layout**: Measure space, plan character positions
2. **Mark positions**: Use center punch to mark each character location
3. **Stamp carefully**:
   - One character at a time
   - Strike firmly and evenly
   - Verify each character before moving to next
4. **Double-check**: Compare stamped key to original character-by-character
5. **Protect edges**: File any sharp edges smooth
6. **Test legibility**: Ensure all characters are clearly readable

**Alternative: Engraving**

If you have access to an engraving tool:
- More precise than hand stamping
- Faster for long keys
- Easier to read
- Still manual verification required

### Storage

- Store separately from paper backups
- Different secure location (geographic diversity)
- Fireproof container not required (metal is fireproof)
- Safety deposit box ideal

## 3. USB Backup (Convenience)

### Materials Needed

- USB drive (32GB minimum, good quality)
- Computer with cryptsetup support (NixOS, Linux)

### Creation Process

```bash
# 1. Insert USB drive, identify device
lsblk
# Assume USB is /dev/sdX - VERIFY THIS!

# WARNING: This will ERASE the USB drive
read -p "USB device (e.g., sdc): " USB_DEV

# 2. Create LUKS encrypted container
sudo cryptsetup luksFormat /dev/${USB_DEV}
# Enter a STRONG passphrase (different from LUKS disk passphrase)
# Store passphrase separately (e.g., in password manager)

# 3. Open encrypted container
sudo cryptsetup open /dev/${USB_DEV} glass-key-backup

# 4. Create filesystem
sudo mkfs.ext4 /dev/mapper/glass-key-backup

# 5. Mount
sudo mkdir -p /mnt/glass-key
sudo mount /dev/mapper/glass-key-backup /mnt/glass-key

# 6. Copy master key
sudo cp ~/master-recovery-key.txt /mnt/glass-key/

# 7. Copy repository bundles
sudo cp ~/glass-key-backup-*/nix-config.bundle /mnt/glass-key/
sudo cp ~/glass-key-backup-*/nix-secrets.bundle /mnt/glass-key/

# 8. Create recovery instructions on USB
sudo tee /mnt/glass-key/RECOVERY.md << 'EOF'
# Glass-Key USB Recovery

## Contents

- master-recovery-key.txt - Age private key for decrypting all secrets
- nix-config.bundle - Complete nix-config git repository (offline)
- nix-secrets.bundle - Complete nix-secrets git repository (offline)
- RECOVERY.md - This file

## Usage

1. Clone repositories from bundles:
   git clone nix-config.bundle nix-config
   git clone nix-secrets.bundle nix-secrets

2. Use master key for decryption:
   export SOPS_AGE_KEY_FILE=/mnt/glass-key/master-recovery-key.txt
   sops -d nix-secrets/sops/shared.yaml

3. Follow full recovery guide:
   See nix-config/docs/disaster-recovery/total-recovery.md

## Security

This USB is LUKS encrypted. Passphrase required to mount.
Store USB and passphrase separately.

## Last Updated

[Date will be in MANIFEST.txt]
EOF

# 9. Unmount and close
sudo umount /mnt/glass-key
sudo cryptsetup close glass-key-backup

echo "USB backup created successfully"
echo "Passphrase required to access: [your passphrase]"
echo "Store USB in secure location offline"
```

### USB Security Properties

- **Encrypted**: LUKS encryption protects if USB is stolen
- **Offline**: Never connect to network or running system
- **Complete**: Contains everything needed (key + repos)
- **Portable**: Easy to transport to recovery location

### Update Schedule

**Quarterly updates** (every 3 months):
- Re-run backup script to create new bundle
- Copy to USB
- Update MANIFEST.txt
- Test decryption

## 4. QR Code Backup (Alternative)

### Benefits

- Eliminates manual typing errors
- Fast scanning with phone camera
- Can be printed on paper backups
- Useful for long age keys

### Creation Process

```bash
# Install QR code generator
nix-shell -p qrencode

# Generate QR code for private key
cat ~/master-recovery-key.txt | qrencode -t PNG -o master-key-qr.png

# Or for direct terminal output
cat ~/master-recovery-key.txt | qrencode -t ANSI

# Print QR code on paper backup
# OR engrave QR code on metal plate (if you have laser engraving)
```

### Testing QR Code

**CRITICAL**: Test QR code scanning BEFORE destroying digital copy:

```bash
# Scan with phone
# Use any QR scanner app
# Verify scanned text EXACTLY matches original key

# Manual verification process:
# 1. Scan QR code with phone
# 2. Compare scanned text character-by-character to original
# 3. If ANY character differs, regenerate QR code
# 4. Only proceed when 100% match confirmed
```

### Storage

- Print QR code on paper backups (alongside text key)
- Provides redundant recovery method
- Faster than typing 100+ character key
- Still keep text version (QR might not scan if damaged)

## Verification Checklist

Before storing backups, verify:

- [ ] Paper backups printed (minimum 3 copies)
- [ ] Keys manually verified character-by-character
- [ ] Paper laminated for water resistance
- [ ] Metal backup stamped/engraved (optional but recommended)
- [ ] Metal backup verified readable
- [ ] USB encrypted with LUKS
- [ ] USB contains: master key + git bundles
- [ ] USB passphrase documented separately
- [ ] QR codes tested and scan correctly (optional)
- [ ] Storage locations identified (3+ different locations)
- [ ] Digital master key securely destroyed after backups

## Testing Backups

**Before storing away**, test each backup format:

```bash
# Test 1: Paper backup
# 1. Manually type key from paper into test file
# 2. Verify decryption works
# 3. Delete test file

# Test 2: Metal backup
# 1. Read key from metal plate
# 2. Verify all characters legible
# 3. Test decryption
# 4. Delete test file

# Test 3: USB backup
# 1. Mount encrypted USB
# 2. Verify files present
# 3. Test bundle cloning
# 4. Test key decryption
# 5. Unmount and close
```

**If any test fails, recreate that backup format.**

## Maintenance

- **Review annually**: Check backups for degradation
- **Update quarterly**: USB backups with latest configs
- **Test annually**: Full recovery test from backups
- **Replace as needed**: Paper if faded, metal if corroded

See `maintenance-schedule.md` for detailed maintenance procedures.

## Next Steps

1. Create storage guide: `glass-key-storage.md`
2. Set up automated repository backups: `repo-backup.md`
3. Test recovery procedure: `total-recovery.md`

## Security Reminders

**The master key on these backups can decrypt EVERYTHING.**

- Store securely (fireproof safe, safety deposit box)
- Multiple locations (not all in one place)
- Never digitize (no photos, scans, digital copies)
- Never network-accessible (no cloud, no password managers)
- Physical security is paramount
- Test recovery procedure annually

If you're not comfortable with this responsibility, reconsider whether you need glass-key backups, or explore future Shamir secret sharing (split key into 3-of-5 shares).
