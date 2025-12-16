# Total Infrastructure Recovery Guide

## Overview

This guide provides step-by-step instructions for rebuilding the entire infrastructure from catastrophic loss using only glass-key backups.

**Disaster Scenario**: "My house burned down, all devices lost, only glass-key backups remain."

**Recovery Goal**: Rebuild complete infrastructure from physical backups alone.

## Prerequisites

### What You Need

1. **Glass-key backups** (at least one):
   - Paper backup with master age key, OR
   - USB backup with master key + git bundles, OR
   - Metal backup with master age key

2. **Hardware**:
   - Any computer capable of running NixOS
   - USB drive for NixOS installer
   - Internet connection (for downloading Nix packages)

3. **Access**:
   - GitHub account (if repos not deleted), OR
   - USB backup with git bundles (if no GitHub access)

4. **Time**:
   - First host: 4-8 hours
   - Complete infrastructure: 5-7 days

### What You Don't Need

- Any existing infrastructure
- Any existing secrets or keys (except master key)
- Any host-specific age keys (will be regenerated)
- Any existing hardware (can use new machines)

## Recovery Timeline

| Day | Activity | Duration |
|-----|----------|----------|
| 1 | Acquire hardware, create installer, install base system | 4-8 hours |
| 1-2 | Restore repos, decrypt secrets, bootstrap first host | 4-8 hours |
| 2 | Verify first host, basic services | 2-4 hours |
| 2-7 | Bootstrap remaining hosts, restore services | Variable |
| 7 | Update glass-key backups with new keys | 2-4 hours |

**Total**: 5-7 days for complete infrastructure recovery

## Phase 1: Acquire Hardware and Install Base System

### Day 1, Hour 0-2: Hardware Acquisition

1. **Purchase or acquire hardware**:
   - Desktop, laptop, or any NixOS-compatible machine
   - Minimum specs: 4GB RAM, 20GB disk
   - Verify hardware compatibility: https://nixos.wiki/wiki/Hardware

2. **Retrieve glass-key backups**:
   - Access home safe (if accessible)
   - Visit bank for safety deposit box
   - Contact trusted person for backup copy
   - Ensure you have master age key

3. **Create NixOS installer USB**:
   ```bash
   # On any Linux machine or live USB
   # Download NixOS ISO
   wget https://channels.nixos.org/nixos-24.11/latest-nixos-minimal-x86_64-linux.iso

   # Write to USB (replace /dev/sdX with your USB device)
   sudo dd if=latest-nixos-minimal-x86_64-linux.iso of=/dev/sdX bs=4M status=progress
   sync
   ```

### Day 1, Hour 2-4: Install Base NixOS

1. **Boot from installer USB**:
   - Boot new machine from USB
   - Select "NixOS installer" from boot menu

2. **Connect to network**:
   ```bash
   # Wired: Should auto-connect via DHCP

   # Wireless:
   sudo systemctl start wpa_supplicant
   wpa_cli
   > add_network
   > set_network 0 ssid "your-network"
   > set_network 0 psk "your-password"
   > enable_network 0
   > quit
   ```

3. **Partition disk** (manual partitioning for now):
   ```bash
   # Simple UEFI + ext4 layout for quick recovery
   # (Can use disko later for production config)

   sudo fdisk /dev/sda
   # Create:
   # - /dev/sda1: 512MB EFI (type ef)
   # - /dev/sda2: Remaining space Linux (type 83)

   # Format
   sudo mkfs.fat -F 32 /dev/sda1
   sudo mkfs.ext4 /dev/sda2

   # Mount
   sudo mount /dev/sda2 /mnt
   sudo mkdir -p /mnt/boot
   sudo mount /dev/sda1 /mnt/boot
   ```

4. **Generate minimal config**:
   ```bash
   sudo nixos-generate-config --root /mnt
   ```

5. **Edit configuration** for network access:
   ```bash
   sudo nano /mnt/etc/nixos/configuration.nix

   # Add:
   networking.networkmanager.enable = true;
   networking.hostName = "recovery-temp";
   users.users.rain.isNormalUser = true;
   users.users.rain.extraGroups = [ "wheel" "networkmanager" ];
   users.users.rain.initialPassword = "changeme";
   ```

6. **Install**:
   ```bash
   sudo nixos-install
   sudo reboot
   ```

### Day 1, Hour 4-6: Install Required Tools

After reboot, login as `rain` (password: `changeme`):

```bash
# Change password immediately
passwd

# Install required tools
nix-shell -p git age sops ssh-to-age

# Generate SSH key for GitHub access (if using GitHub)
ssh-keygen -t ed25519 -C "recovery@$(hostname)"
cat ~/.ssh/id_ed25519.pub
# Add to GitHub: https://github.com/settings/keys
```

## Phase 2: Restore Repositories and Decrypt Secrets

### Day 1, Hour 6-7: Clone Repositories

**Option A: From USB Backup (No GitHub Required)**

```bash
# Mount USB backup
sudo mkdir -p /mnt/usb
sudo mount /dev/sdb1 /mnt/usb  # Adjust device as needed

# If USB is LUKS encrypted
sudo cryptsetup open /dev/sdb1 glass-key-backup
sudo mount /dev/mapper/glass-key-backup /mnt/usb

# Clone from bundles
cd ~
git clone /mnt/usb/glass-key-backup-*/nix-config.bundle nix-config
git clone /mnt/usb/glass-key-backup-*/nix-secrets.bundle nix-secrets

# Copy master key
cp /mnt/usb/glass-key-backup-*/master-recovery-key.txt ~/.
chmod 600 ~/master-recovery-key.txt

# Verify clones
cd nix-config && git log -1
cd ../nix-secrets && git log -1
cd ~
```

**Option B: From GitHub (If Available)**

```bash
cd ~
git clone git@github.com:[your-username]/nix-config
git clone git@github.com:[your-username]/nix-secrets

# Type master key from paper backup
cat > ~/master-recovery-key.txt << 'EOF'
AGE-SECRET-KEY-1[type-private-key-from-paper-backup]
EOF
chmod 600 ~/master-recovery-key.txt
```

**Verify repositories**:
```bash
cd ~/nix-config && git log --oneline -5
cd ~/nix-secrets && git log --oneline -5
cd ~
```

### Day 1, Hour 7-8: Decrypt and Verify Secrets

```bash
# Set master key for SOPS
export SOPS_AGE_KEY_FILE=~/master-recovery-key.txt

# Test decryption of shared secrets
sops -d nix-secrets/sops/shared.yaml
# Should show decrypted YAML with secrets

# Test decryption of host secrets (if any exist)
ls nix-secrets/sops/
# Try decrypting a host-specific secret
sops -d nix-secrets/sops/[hostname].yaml

# If decryption works, master key is correctly configured
```

**If decryption fails**:
- Verify master key was typed correctly (check character by character)
- Verify `.sops.yaml` includes master key in recipients
- Try re-typing master key from backup

## Phase 3: Bootstrap First Host

### Day 1-2, Hour 8-12: Run Bootstrap

Choose a hostname for the first recovery host:

```bash
cd ~/nix-config

# If recovering existing host configuration
HOSTNAME="malphas"  # Or whichever host you want to rebuild

# If creating new recovery host
HOSTNAME="recovery-primary"

# Run bootstrap with master key
sudo SOPS_AGE_KEY_FILE=~/master-recovery-key.txt \
  ./scripts/bootstrap-nixos.sh \
  -n "$HOSTNAME" \
  -d /dev/sda \
  -k ~/.ssh/id_ed25519

# Bootstrap will:
# 1. Scan new SSH host key
# 2. Generate NEW host age key from SSH key
# 3. Add host age key to nix-secrets/.sops.yaml
# 4. Rekey all secrets (encrypted for master + new host key)
# 5. Run nixos-anywhere to install
# 6. Copy nix-config and nix-secrets to host
# 7. Rebuild system
```

**Bootstrap interactive prompts**:
- Run nixos-anywhere? → Yes
- Generate hardware config? → Yes (if new hardware)
- Set LUKS passphrase? → Yes (or use default "passphrase")
- Generate host age key? → Yes
- Copy configs? → Yes
- Rebuild immediately? → Yes

**Expected duration**: 1-2 hours (depends on network speed)

### Day 2, Hour 12-14: Verify First Host

After bootstrap completes and system reboots:

```bash
# Login to new host (via SSH or console)
ssh rain@[hostname]

# 1. Verify secrets are decrypted
sudo ls /run/secrets/
# Should show decrypted secret files

# 2. Check services are running
systemctl status
systemctl status sops-nix.service

# 3. Verify Tailscale (if configured)
tailscale status
# Should show connected to tailnet

# 4. Verify SSH works
ssh localhost
# Should connect without password (key-based)

# 5. Check system logs for errors
journalctl -p err -b
# Should be minimal errors
```

**If verification fails**:
- Check `/var/log/sops-nix.log` for decryption errors
- Verify host age key in `.sops.yaml`
- Re-run `just rekey` in nix-secrets
- Rebuild: `sudo nixos-rebuild switch --flake .#$HOSTNAME`

## Phase 4: Rebuild Infrastructure

### Day 2-7: Bootstrap Remaining Hosts

For each additional host:

```bash
# On first host (or recovery machine with nix-config)
cd ~/nix-config

# Bootstrap next host
sudo SOPS_AGE_KEY_FILE=~/master-recovery-key.txt \
  ./scripts/bootstrap-nixos.sh \
  -n [next-hostname] \
  -d [target-device] \
  -k ~/.ssh/id_ed25519

# Each host gets new age key
# All secrets remain encrypted for master key
```

**Prioritization**:
1. **First**: Core server (services, storage)
2. **Second**: Primary desktop (daily driver)
3. **Third**: Secondary machines
4. **Last**: Test VMs, experimental hosts

**Parallelization**:
- Can bootstrap multiple hosts simultaneously
- Each needs separate hardware
- Network bandwidth is bottleneck

### Service Restoration Order

1. **Core Infrastructure** (Day 2-3):
   - Tailscale (connectivity)
   - SSH (access)
   - SOPS (secrets)

2. **Essential Services** (Day 3-4):
   - File sync (Syncthing)
   - Password manager (if self-hosted)
   - Git server (if self-hosted)

3. **Applications** (Day 4-6):
   - Desktop environment
   - Development tools
   - Media services

4. **Optional Services** (Day 6-7):
   - Game servers
   - Experimental services
   - Test environments

## Phase 5: Update Glass-Key Backups

### Day 7: Create New Backups

After infrastructure is rebuilt:

```bash
cd ~/nix-config

# 1. Create new backup bundle (new host keys in .sops.yaml)
./scripts/create-glass-key-backup.sh

# 2. Copy to USB
sudo cp -r ~/glass-key-backup-$(date +%Y%m%d) /mnt/usb/

# 3. Verify
cd /mnt/usb/glass-key-backup-$(date +%Y%m%d)
git bundle verify nix-config.bundle
git bundle verify nix-secrets.bundle
sha256sum -c MANIFEST.txt

# 4. Update paper backups (if master key changed)
# - Print new master key
# - Laminate
# - Store in secure locations

# 5. Update documentation
# - Record new backup date
# - Update inventory
```

## Recovery Time Estimates

Based on typical infrastructure:

| Phase | Activity | Time |
|-------|----------|------|
| 1 | Hardware + Base Install | 4-6 hours |
| 2 | Clone Repos + Decrypt | 1-2 hours |
| 3 | Bootstrap First Host | 2-4 hours |
| 4 | Verify First Host | 1-2 hours |
| **Day 1-2 Total** | **First working host** | **8-14 hours** |
| 5 | Bootstrap Host 2-5 | 4-8 hours |
| 6 | Service Restoration | 8-16 hours |
| 7 | Verification | 4-8 hours |
| 8 | Update Backups | 2-4 hours |
| **Total** | **Complete infrastructure** | **26-50 hours over 5-7 days** |

**Factors affecting time**:
- Network speed (Nix downloads)
- Hardware availability
- Number of hosts
- Service complexity
- Your familiarity with process

## Troubleshooting

### Master Key Won't Decrypt Secrets

**Symptom**: `sops -d` fails with master key

**Causes**:
1. Master key not in `.sops.yaml` when secrets were encrypted
2. Master key typed incorrectly from paper backup
3. Wrong master key (old/rotated key)

**Solutions**:
```bash
# Verify master key format
cat ~/master-recovery-key.txt
# Should start with: AGE-SECRET-KEY-1

# Check .sops.yaml has master key
grep -A 5 "keys:" nix-secrets/.sops.yaml
# Should show master key in list

# Verify public key matches
age-keygen -y ~/master-recovery-key.txt
# Compare to public key in .sops.yaml

# Try decrypting specific file
SOPS_AGE_KEY_FILE=~/master-recovery-key.txt sops -d nix-secrets/sops/shared.yaml
```

### Git Bundle Clone Fails

**Symptom**: `fatal: not a git bundle`

**Causes**:
1. Corrupted bundle file
2. Incomplete USB copy
3. Wrong file

**Solutions**:
```bash
# Verify bundle
git bundle verify /path/to/nix-config.bundle

# Check file size (should be >1MB)
ls -lh /path/to/nix-config.bundle

# Try alternative backup source
# - Different USB
# - Clone from GitHub if available
```

### Bootstrap Fails

**Symptom**: Bootstrap script errors out

**Common issues**:
1. Network connectivity lost
2. Disk partitioning failed
3. Hardware incompatibility

**Solutions**:
```bash
# Check network
ping 1.1.1.1

# Verify disk device
lsblk
# Use correct device in -d flag

# Check bootstrap logs
tail -f /tmp/nixos-anywhere.log

# Retry with --debug flag
./scripts/bootstrap-nixos.sh --debug -n hostname -d /dev/sda -k ~/.ssh/key
```

### Services Won't Start

**Symptom**: Systemd services failing after rebuild

**Check**:
```bash
# View failed services
systemctl --failed

# Check specific service
systemctl status [service-name]
journalctl -u [service-name]

# Common issues:
# - Secrets not decrypted: Check /run/secrets/
# - Network not ready: Wait for network-online.target
# - Dependencies missing: Check service dependencies
```

## Validation Checklist

After recovery, verify:

- [ ] All hosts bootstrapped and running
- [ ] All secrets decrypt correctly (`sudo ls /run/secrets/`)
- [ ] SSH access works (password-less with keys)
- [ ] Tailscale connected to tailnet
- [ ] Essential services running (check `systemctl status`)
- [ ] Data restored (Syncthing, backups)
- [ ] Desktop environment functional (if desktop role)
- [ ] Development tools working (if development role)
- [ ] Glass-key backups updated with new host keys
- [ ] Physical backups updated (if master key changed)
- [ ] Recovery test documented (results and lessons learned)

## Post-Recovery Actions

### Immediate (Day 7)

1. **Update backups**:
   - Create new USB backup bundle
   - Update paper backups if needed
   - Store securely

2. **Document recovery**:
   - Record actual recovery time
   - Note any issues encountered
   - Update this guide with improvements
   - File: `.planning/phases/17-physical-security/recovery-test-$(date +%Y-%m-%d).md`

3. **Verify security**:
   - All secrets properly encrypted
   - No secrets in git history
   - Master key not stored digitally

### Short-term (Week 2)

1. **Full system verification**:
   - Test all services
   - Verify data integrity
   - Check backups are running

2. **Security audit**:
   - Review access logs
   - Verify firewall rules
   - Check for unauthorized access

3. **Performance tuning**:
   - Optimize configurations
   - Remove unnecessary services
   - Update hardware if needed

### Long-term (Month 1)

1. **Infrastructure improvements**:
   - Address any recovery pain points
   - Automate recovery steps where possible
   - Improve documentation

2. **Backup verification**:
   - Test new backup procedures
   - Verify all backup locations
   - Update storage strategy if needed

3. **Plan next steps**:
   - Consider Shamir secret sharing (future enhancement)
   - Evaluate disaster scenarios
   - Update runbooks

## Lessons Learned Template

Document your recovery in `.planning/phases/17-physical-security/recovery-test-YYYY-MM-DD.md`:

```markdown
# Recovery Test - [Date]

## Scenario
[Describe what you were recovering from]

## Timeline
- Hour 0: [Started]
- Hour X: [Milestone]
- Hour Y: [Completed]
- Total: [X hours]

## What Worked
- [List successes]

## What Failed
- [List failures and how resolved]

## Improvements Needed
- [Documentation updates]
- [Process improvements]
- [Tool enhancements]

## Updated Estimates
- First host: [X hours] (estimated: Y hours)
- Full recovery: [X hours] (estimated: Y hours)
```

## Next Steps

- Review `maintenance-schedule.md` for ongoing maintenance
- Schedule annual recovery tests
- Update `glass-key-storage.md` locations
- Share lessons learned with future self

## Emergency Contact

If you're reading this during a real disaster:

1. **Don't panic** - You planned for this
2. **Start with Phase 1** - Get hardware and base install
3. **Follow steps sequentially** - Don't skip ahead
4. **Document as you go** - Note any deviations
5. **Ask for help** - NixOS community, friends, this guide

**You can rebuild everything. Take your time. Be methodical.**

## References

- Master key setup: `master-key-setup.md`
- Physical backups: `glass-key-creation.md`
- Storage strategy: `glass-key-storage.md`
- Repository backups: `repo-backup.md`
- Bootstrap script: `scripts/bootstrap-nixos.sh`
- Backup script: `scripts/create-glass-key-backup.sh`
