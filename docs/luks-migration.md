# LUKS Full Disk Encryption Migration Guide

**Last Updated**: 2025-12-16

This guide covers migrating NixOS hosts from unencrypted disks to LUKS full disk encryption using the `btrfs-luks-impermanence` layout.

## Overview

LUKS (Linux Unified Key Setup) provides full disk encryption, protecting your data at rest. This guide shows how to:
- Migrate existing hosts to encrypted disks
- Set up password-only unlock (YubiKey optional)
- Maintain impermanence with encrypted /persist
- Recover from migration failures

## Prerequisites

Before starting migration, ensure you have:

1. **Backup System**: Full backup of all important data
2. **Repository Access**: Both nix-config and nix-secrets committed and pushed
3. **Recovery Media**: Bootable NixOS installer USB
4. **Access Credentials**:
   - Root password or SSH key for target host
   - LUKS passphrase chosen and stored securely
   - Age keys backed up (if rotating)
5. **Time Window**: 1-3 hours of downtime acceptable
6. **Testing**: Procedures validated on test VM (misery)

## Pre-Migration Checklist

### 1. Backup Critical Data

```bash
# Backup /persist directory (contains important state)
rsync -av --progress /persist/ /backup/persist-$(date +%Y%m%d)/

# Backup SSH keys
cp -r ~/.ssh /backup/ssh-keys-$(date +%Y%m%d)

# Backup any custom data directories
rsync -av --progress /home/ /backup/home-$(date +%Y%m%d)/
```

### 2. Verify Repository Status

```bash
# Ensure nix-config is clean and pushed
cd ~/src/nix/nix-config
git status
git push

# Ensure nix-secrets is clean and pushed
cd ~/src/nix/nix-secrets
git status
git push
```

### 3. Document Current Configuration

```bash
# Save partition layout
lsblk -f > /backup/pre-migration-lsblk.txt
df -h > /backup/pre-migration-df.txt

# Save hardware config
cp /etc/nixos/hardware-configuration.nix /backup/

# List persistent files
find /persist -type f > /backup/persist-files.txt
```

### 4. Test Glass-Key Recovery

Before encrypting, verify you can recover secrets:
1. Back up age key: `cp /var/lib/sops-nix/key.txt /backup/age-key.txt`
2. Test decryption: `cd ~/src/nix/nix-secrets && sops -d sops/shared.yaml`
3. Verify backup works: `SOPS_AGE_KEY_FILE=/backup/age-key.txt sops -d sops/shared.yaml`

### 5. Prepare Installation Media

```bash
# Build installer ISO (or download from nixos.org)
nix build .#nixosConfigurations.iso.config.system.build.isoImage

# Write to USB (replace /dev/sdX with your USB device)
sudo dd if=result/iso/nixos.iso of=/dev/sdX bs=4M status=progress
sync
```

## Migration Procedure

### Step 1: Update Host Configuration

Edit the target host's `hosts/<hostname>/default.nix`:

```nix
{
  disks = {
    enable = true;
    layout = "btrfs-luks-impermanence";  # Enable LUKS + impermanence
    device = "/dev/nvme0n1";  # or /dev/sda, /dev/vda, etc.
    withSwap = true;
    swapSize = "16";  # GB, adjust based on RAM
  };

  # Rest of configuration...
}
```

Commit and push:
```bash
git add hosts/<hostname>/default.nix
git commit -m "feat(<hostname>): enable LUKS encryption"
git push
```

### Step 2: Boot from Installer

1. Insert bootable USB drive
2. Reboot and enter BIOS/UEFI boot menu
3. Select USB drive
4. Boot into NixOS installer

### Step 3: Run Bootstrap Script

From your development machine (or another host with SSH access to installer):

```bash
cd ~/src/nix/nix-config

# Run bootstrap with impermanence flag
./scripts/bootstrap-nixos.sh \
  -n <hostname> \
  -d <ip-address> \
  -k ~/.ssh/id_ed25519 \
  --impermanence
```

The script will:
1. Prompt for LUKS passphrase (choose a strong password)
2. Generate new SSH host keys
3. Format disk with LUKS encryption
4. Install NixOS with your configuration
5. Generate age keys for secrets

**IMPORTANT**: Store the LUKS passphrase in your password manager immediately!

### Step 4: First Boot and Verification

After installation completes:

1. **Remove USB drive** and reboot
2. **Enter LUKS passphrase** at boot prompt
3. **Verify system boots correctly**
4. **Check encryption is active**:

```bash
# Verify LUKS is active
lsblk -f | grep crypto_LUKS
# Should show: crypto_LUKS
cryptsetup status encrypted-nixos
# Should show: /dev/mapper/encrypted-nixos is active

# Verify age key is inside encrypted volume
stat /var/lib/sops-nix/key.txt
df -h /var/lib/sops-nix/
# Should show mounted from encrypted partition

# Verify secrets decrypt correctly
ls -la /run/secrets/
# Should show your expected secrets

# Test impermanence
ls -la /
# Root should be minimal (only /boot, /nix, /persist, etc.)
```

### Step 5: Restore /persist Data

If you had important data in /persist before migration:

```bash
# From backup location (on another host or external drive)
rsync -av --progress /backup/persist-<date>/ root@<hostname>:/persist/

# Verify ownership and permissions
ssh root@<hostname> "chown -R rain:users /persist/home/rain"
```

### Step 6: Final Configuration

After successful boot:

```bash
# Update flake to pick up new host keys
cd ~/src/nix/nix-config
nix flake update nix-secrets

# Rebuild to ensure everything works
sudo nixos-rebuild switch --flake .#<hostname>

# Reboot to verify impermanence works
sudo reboot
```

After reboot, enter LUKS passphrase again and verify:
- System boots normally
- Secrets decrypt correctly
- Services start as expected

## Rollback Procedure

If migration fails or causes issues:

### 1. Boot from Installer Again

Boot back into the NixOS installer USB.

### 2. Restore Previous Configuration

Edit host config to remove LUKS:

```nix
{
  disks = {
    enable = true;
    layout = "btrfs";  # Back to unencrypted
    device = "/dev/nvme0n1";
    withSwap = true;
    swapSize = "16";
  };
}
```

### 3. Reinstall Without LUKS

Run bootstrap script again:
```bash
./scripts/bootstrap-nixos.sh \
  -n <hostname> \
  -d <ip-address> \
  -k ~/.ssh/id_ed25519
```

### 4. Restore Data from Backup

```bash
rsync -av /backup/persist-<date>/ root@<hostname>:/persist/
rsync -av /backup/home-<date>/ root@<hostname>:/home/
```

## Post-Migration Tasks

### Verify Security Properties

```bash
# 1. Encryption active
cryptsetup status encrypted-nixos

# 2. Age keys protected
ls -la /var/lib/sops-nix/key.txt
# Should be mode 600, inside encrypted volume

# 3. Secrets working
systemctl status sops-nix
ls /run/secrets/

# 4. Boot requires password
# Reboot and verify LUKS prompt appears

# 5. Impermanence working
# After reboot, check / is clean
ls -la /
```

### Store Passphrase Securely

1. **Password Manager**: Add LUKS passphrase with:
   - Host: `<hostname> LUKS`
   - Username: `root`
   - Password: `<your-passphrase>`
   - Notes: "Disk encryption passphrase - required at boot"

2. **Offline Backup**: Write passphrase on paper, store in safe location

3. **Recovery Instructions**: Document in your password manager:
   - How to boot from USB
   - Location of bootstrap script
   - Glass-key recovery procedure

### Test Recovery Scenarios

1. **Cold boot**: Power off completely, boot, enter passphrase
2. **Wrong passphrase**: Try incorrect password, verify fallback works
3. **Emergency access**: Test glass-key recovery procedure
4. **Secrets rotation**: Rotate one secret to verify SOPS still works

## Optional: YubiKey Enrollment

After successful LUKS migration, you can add YubiKey unlock:

### Prerequisites
- YubiKey 5 or later with FIDO2 support
- yubikey-manager installed: `nix-shell -p yubikey-manager`
- System booted and unlocked with password

### Enrollment Steps

```bash
# 1. Identify LUKS partition
lsblk -f | grep crypto_LUKS
# Usually /dev/nvme0n1p2 or /dev/sda2

# 2. Enroll YubiKey
sudo systemd-cryptenroll --fido2-device=auto /dev/nvme0n1p2
# Follow prompts to touch YubiKey

# 3. Verify enrollment
sudo cryptsetup luksDump /dev/nvme0n1p2 | grep -A5 "Token"
# Should show LUKS2 token with type: systemd-fido2

# 4. Update crypttab (optional, for automatic detection)
# Edit /etc/crypttab to add: fido2-device=auto
```

### Testing YubiKey Unlock

```bash
# Reboot and test
sudo reboot

# At LUKS prompt:
# - Insert YubiKey and touch when it blinks (automatic unlock)
# - OR press ESC and enter password (fallback)
```

### Enrolling Multiple YubiKeys

```bash
# Enroll second YubiKey (backup)
sudo systemd-cryptenroll --fido2-device=auto /dev/nvme0n1p2
# Insert second YubiKey when prompted

# Verify both are enrolled
sudo cryptsetup luksDump /dev/nvme0n1p2 | grep "Token:"
# Should show multiple tokens
```

### Removing YubiKey Enrollment

```bash
# List token slots
sudo cryptsetup luksDump /dev/nvme0n1p2

# Remove specific token (replace N with slot number)
sudo systemd-cryptenroll --wipe-slot=N /dev/nvme0n1p2
```

## Troubleshooting

### Issue: Can't Boot - Wrong Passphrase

**Symptoms**: System prompts for passphrase but rejects it

**Solutions**:
1. Try passphrase again (check keyboard layout)
2. Boot from USB installer
3. Unlock LUKS manually:
   ```bash
   cryptsetup luksOpen /dev/nvme0n1p2 encrypted-nixos
   # Enter correct passphrase

   # Mount and chroot to change password
   mount /dev/mapper/encrypted-nixos-root /mnt
   nixos-enter --root /mnt
   cryptsetup luksChangeKey /dev/nvme0n1p2
   ```

### Issue: Secrets Don't Decrypt

**Symptoms**: `/run/secrets/` is empty or permission denied

**Solutions**:
1. Check age key exists: `stat /var/lib/sops-nix/key.txt`
2. Verify key permissions: `ls -la /var/lib/sops-nix/`
3. Check sops-nix service: `systemctl status sops-nix`
4. Manually decrypt to test: `sops -d ~/src/nix/nix-secrets/sops/shared.yaml`
5. If needed, restore age key from backup
6. Rekey secrets: `cd ~/src/nix/nix-secrets && just rekey`

### Issue: Impermanence Not Working

**Symptoms**: Files persist in / after reboot

**Solutions**:
1. Check mount points: `mount | grep btrfs`
2. Verify root is tmpfs: `df -h / | grep tmpfs`
3. Check persist paths: `ls /persist/`
4. Review impermanence config: `/etc/nixos/configuration.nix`
5. Ensure @persist subvolume exists: `btrfs subvolume list /`

### Issue: Boot Hangs at LUKS Prompt

**Symptoms**: System waits indefinitely for passphrase

**Solutions**:
1. Enter passphrase (may take a moment)
2. If frozen, try Ctrl+C then re-enter
3. Check keyboard connection (USB may need time to initialize)
4. Boot with `nomodeset` kernel parameter if graphics issue
5. Check LUKS device UUID matches crypttab

### Issue: Performance Degradation

**Symptoms**: System slower after enabling LUKS

**Solutions**:
1. Verify SSD TRIM enabled: `grep discard /etc/crypttab`
2. Check LUKS settings: `cryptsetup luksDump /dev/nvme0n1p2 | grep Cipher`
3. Enable `allowDiscards` in disko config (already default)
4. Verify btrfs compression: `mount | grep compress=zstd`

## Migration Checklist Template

Use this checklist for each host migration:

- [ ] Full backup completed
- [ ] Repositories pushed (nix-config, nix-secrets)
- [ ] Glass-key recovery tested
- [ ] Installation USB prepared
- [ ] LUKS passphrase chosen and documented
- [ ] Host config updated (disks.layout = "btrfs-luks-impermanence")
- [ ] Config committed and pushed
- [ ] Booted from installer
- [ ] Bootstrap script executed
- [ ] LUKS passphrase entered during install
- [ ] System rebooted successfully
- [ ] LUKS prompt works at boot
- [ ] Secrets decrypt correctly
- [ ] /persist data restored
- [ ] Final rebuild completed
- [ ] Passphrase stored in password manager
- [ ] YubiKey enrolled (optional)
- [ ] Recovery procedure documented
- [ ] Test cold boot
- [ ] Verify impermanence works
- [ ] Old backup media labeled and stored

## Security Notes

### What LUKS Protects

- Cold boot attacks (device powered off)
- Physical theft of powered-off device
- Unauthorized disk access (disk removed from system)
- Age keys at rest
- Persistent data in /persist

### What LUKS Does NOT Protect

- Hot boot attacks (stolen while running)
- RAM dump attacks (DMA attacks)
- Compromised bootloader
- Evil maid attacks (physical access while running)
- Network attacks (secrets in memory)

### Best Practices

1. **Strong Passphrase**: Use diceware or 4+ word phrase
2. **Secure Storage**: Password manager + offline backup
3. **Regular Testing**: Test recovery quarterly
4. **Backup Keys**: Keep age keys backed up offline
5. **Physical Security**: Lock screen when away
6. **Auto-lock**: Enable screen lock after idle timeout
7. **Shutdown vs Suspend**: Shutdown when leaving device unattended

## Additional Resources

- [Arch Wiki: dm-crypt](https://wiki.archlinux.org/title/Dm-crypt)
- [NixOS Wiki: Full Disk Encryption](https://nixos.wiki/wiki/Full_Disk_Encryption)
- [Disko Documentation](https://github.com/nix-community/disko)
- [LUKS FAQ](https://gitlab.com/cryptsetup/cryptsetup/-/wikis/FrequentlyAskedQuestions)

## Support

If you encounter issues:
1. Check troubleshooting section above
2. Review bootstrap script logs
3. Test on misery VM first
4. Refer to Phase 17 planning documents

For system-specific help, document:
- Host configuration
- Error messages
- Steps to reproduce
- Output of diagnostic commands
