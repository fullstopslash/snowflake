# Glass-Key Maintenance Schedule

## Overview

Regular maintenance of glass-key backups is critical for disaster recovery readiness. This schedule ensures backups remain current, accessible, and functional.

**Key Principle**: Untested backups are not backups. Regular testing validates the recovery procedure works when needed.

## Maintenance Frequencies

| Frequency | Tasks | Duration | Priority |
|-----------|-------|----------|----------|
| Monthly | Quick verification | 15-30 min | Medium |
| Quarterly | USB update, bundle refresh | 1-2 hours | High |
| Annually | Full recovery test, physical audit | 4-8 hours | Critical |
| After changes | Immediate re-snapshot | 30-60 min | High |

## Monthly Tasks (15-30 minutes)

**Schedule**: 1st of each month
**Priority**: Medium
**Can be automated**: Partially

### Checklist

- [ ] Verify USB backup is accessible
- [ ] Check git bundle integrity
- [ ] Verify checksums
- [ ] Review backup locations documentation

### Commands

```bash
# Mount USB backup (if encrypted)
sudo cryptsetup open /dev/sdX glass-key-backup
sudo mount /dev/mapper/glass-key-backup /mnt/glass-key

# Navigate to latest backup
cd /mnt/glass-key/glass-key-backup-*

# Verify git bundles
git bundle verify nix-config.bundle
git bundle verify nix-secrets.bundle
# Expected: "nix-config.bundle is okay"
# Expected: "nix-secrets.bundle is okay"

# Verify checksums
sha256sum -c MANIFEST.txt
# Expected: All files "OK"

# Check file dates
ls -lh
# Verify backup is from expected date

# Unmount
cd ~
sudo umount /mnt/glass-key
sudo cryptsetup close glass-key-backup
```

### What to Look For

**Good signs**:
- Bundles verify successfully
- All checksums match
- Files readable
- Dates match expected

**Bad signs**:
- Bundle verification fails → Re-create backup immediately
- Checksum mismatches → USB corruption, re-copy backup
- Cannot mount USB → Test on different machine
- Files unreadable → Backup is corrupted

### If Issues Found

1. **Immediate**: Create new backup
2. **Diagnose**: Why did backup fail?
3. **Fix**: USB hardware issue? Storage location issue?
4. **Document**: Record issue and resolution

## Quarterly Tasks (1-2 hours)

**Schedule**: January 1, April 1, July 1, October 1
**Priority**: High
**Can be automated**: Mostly

### Checklist

- [ ] Create fresh backup bundle
- [ ] Update USB backup
- [ ] Verify new backup integrity
- [ ] Delete old backups (keep latest + previous)
- [ ] Review paper backups for degradation
- [ ] Update backup locations documentation

### Commands

```bash
# 1. Create new backup bundle
cd ~/nix-config
./scripts/create-glass-key-backup.sh

# Expected output:
# ✓ Glass-key backup created: /home/rain/glass-key-backup-YYYYMMDD

# 2. Mount USB
sudo cryptsetup open /dev/sdX glass-key-backup
sudo mount /dev/mapper/glass-key-backup /mnt/glass-key

# 3. Copy new backup to USB
sudo cp -r ~/glass-key-backup-$(date +%Y%m%d) /mnt/glass-key/

# 4. Verify new backup
cd /mnt/glass-key/glass-key-backup-$(date +%Y%m%d)
git bundle verify nix-config.bundle
git bundle verify nix-secrets.bundle
sha256sum -c MANIFEST.txt

# 5. Delete old backups (keep current + previous)
cd /mnt/glass-key
ls -t | grep glass-key-backup | tail -n +3 | xargs sudo rm -rf

# 6. Unmount
cd ~
sudo umount /mnt/glass-key
sudo cryptsetup close glass-key-backup

# 7. Clean up local backup
rm -rf ~/glass-key-backup-*
```

### Physical Backup Review

```bash
# Check paper backups
# 1. Retrieve one paper backup from home safe
# 2. Visually inspect for:
#    - Fading (laser print shouldn't fade, but check)
#    - Water damage (lamination should protect)
#    - Physical damage (tears, creases)
# 3. Verify key is still legible
# 4. Re-laminate if degradation detected
# 5. Return to safe

# Optional: Check metal backup
# 1. If accessible (safety deposit box visit)
# 2. Inspect for corrosion
# 3. Verify stamped characters still legible
# 4. Clean if needed (stainless steel should be fine)
```

### Documentation Update

```bash
# Update backup inventory (offline document)
# Record:
# - Date of latest backup: YYYY-MM-DD
# - Git commit hashes: nix-config, nix-secrets
# - Number of hosts in .sops.yaml: X
# - Master key status: (same|rotated)
# - USB backup location: (verified accessible)
# - Paper backup locations: (all verified)
```

## Annual Tasks (4-8 hours)

**Schedule**: January 1 (or your chosen anniversary date)
**Priority**: CRITICAL
**Can be automated**: No (requires manual testing)

### Checklist

- [ ] Full recovery test in VM
- [ ] Verify all backup locations accessible
- [ ] Inspect all physical backups
- [ ] Test USB encryption
- [ ] Review and update documentation
- [ ] Update executor instructions
- [ ] Schedule next year's test

### Full Recovery Test

**Purpose**: Validate that recovery procedure works end-to-end

**Requirements**:
- Test VM or spare hardware (NOT production)
- 4-8 hours of time
- Glass-key backups accessible

**Procedure**:

```bash
# 1. Create test VM
# Use any virtualization: VirtualBox, QEMU, libvirt, etc.
# - 4GB RAM
# - 20GB disk
# - Network enabled

# 2. Boot NixOS installer
# Download: https://nixos.org/download.html
# Boot VM from ISO

# 3. Install minimal NixOS
# Follow installation guide for basic setup

# 4. After reboot, install tools
nix-shell -p git age sops

# 5. Clone from bundles (test offline recovery)
# Mount USB backup in VM
git clone /path/to/nix-config.bundle nix-config
git clone /path/to/nix-secrets.bundle nix-secrets

# 6. Copy master key from backup
cp /path/to/master-recovery-key.txt ~/.
chmod 600 ~/master-recovery-key.txt

# 7. Test secret decryption
export SOPS_AGE_KEY_FILE=~/master-recovery-key.txt
sops -d nix-secrets/sops/shared.yaml
# Should show decrypted secrets

# 8. Bootstrap test host (optional - time intensive)
cd nix-config
sudo SOPS_AGE_KEY_FILE=$SOPS_AGE_KEY_FILE \
  ./scripts/bootstrap-nixos.sh -n recovery-test -d /dev/vda -k ~/.ssh/id_ed25519

# 9. Verify (if bootstrapped)
sudo ls /run/secrets/
systemctl status

# 10. Document results
# See template below
```

### Recovery Test Documentation

Create: `.planning/phases/17-physical-security/recovery-test-$(date +%Y-%m-%d).md`

```markdown
# Glass-Key Recovery Test - [Date]

## Test Scenario

Simulated total infrastructure loss, recovery from USB backup only.

## Test Environment

- VM platform: [VirtualBox/QEMU/etc]
- RAM: 4GB
- Disk: 20GB
- Network: Enabled
- Backup source: USB encrypted backup (YYYY-MM-DD)

## Timeline

- Hour 0: Started VM creation
- Hour 1: NixOS installer booted
- Hour 2: Base system installed
- Hour 3: Tools installed, repos cloned
- Hour 4: Secrets decrypted successfully
- Hour 5: Bootstrap started (optional)
- Hour X: Test completed

**Total time**: X hours

## What Worked

- ✅ USB backup accessible and mountable
- ✅ Git bundles cloned successfully
- ✅ Master key decrypted secrets
- ✅ Recovery documentation was clear
- [Add successes]

## What Failed / Issues Encountered

- ❌ [Issue description]
  - Root cause: [Why it failed]
  - Resolution: [How fixed]
  - Documentation update needed: [Yes/No]

## Improvements Needed

### Documentation
- [List documentation updates]

### Process
- [List process improvements]

### Tooling
- [List tool enhancements]

## Updated Time Estimates

Based on actual test:
- Base install: X hours (previous estimate: Y hours)
- Clone and decrypt: X hours (previous estimate: Y hours)
- Bootstrap: X hours (previous estimate: Y hours)
- Total recovery: X hours (previous estimate: Y hours)

## Test Validation

- [ ] USB backup accessible
- [ ] Bundles cloned successfully
- [ ] Secrets decrypted with master key
- [ ] Recovery documentation followed
- [ ] Issues documented
- [ ] Documentation updated
- [ ] Next test scheduled

## Next Test

Scheduled for: [Date next year]
```

### Physical Backup Audit

Visit all backup locations:

**Home Safe**:
- [ ] Safe is accessible (know combination/key)
- [ ] Paper backup present and legible
- [ ] USB backup present
- [ ] Recovery instructions present
- [ ] Last updated: _______

**Safety Deposit Box** (or off-site location):
- [ ] Box accessible (have key, ID accepted)
- [ ] Paper backup present and legible
- [ ] Metal backup present (if using)
- [ ] No corrosion or degradation
- [ ] Last verified: _______

**Trusted Person**:
- [ ] Contact person, confirm they still have envelope
- [ ] Envelope still sealed
- [ ] Person willing to continue storing
- [ ] Update contact info if changed
- [ ] Last contact: _______

**Estate Executor**:
- [ ] Executor knows backup locations
- [ ] Executor instructions up to date
- [ ] Legal documents reference backups
- [ ] Technical contact info current
- [ ] Last review: _______

### Documentation Review

```bash
# Review all disaster recovery docs
cd ~/nix-config/docs/disaster-recovery/

# Check each file for accuracy
cat master-key-setup.md        # Still accurate?
cat glass-key-creation.md      # Process still valid?
cat glass-key-storage.md       # Locations current?
cat repo-backup.md             # Script still works?
cat total-recovery.md          # Procedure tested and validated?
cat maintenance-schedule.md    # This file - still relevant?

# Update any outdated information
# Commit changes to nix-config
```

## After Major Changes (30-60 minutes)

**Trigger Events**:
- New host added to infrastructure
- Host removed from infrastructure
- Master key rotated
- .sops.yaml modified
- Infrastructure redesign
- Bootstrap process changed

### Checklist

- [ ] Create new backup bundle immediately
- [ ] Update USB backup
- [ ] Update paper backups (if master key changed)
- [ ] Test new backup
- [ ] Document change

### Commands

```bash
# Same as quarterly update, but triggered by event
cd ~/nix-config
./scripts/create-glass-key-backup.sh

# Copy to USB
sudo cryptsetup open /dev/sdX glass-key-backup
sudo mount /dev/mapper/glass-key-backup /mnt/glass-key
sudo cp -r ~/glass-key-backup-$(date +%Y%m%d) /mnt/glass-key/
cd /mnt/glass-key/glass-key-backup-$(date +%Y%m%d)
git bundle verify nix-config.bundle
git bundle verify nix-secrets.bundle
sha256sum -c MANIFEST.txt
cd ~
sudo umount /mnt/glass-key
sudo cryptsetup close glass-key-backup

# If master key changed, update paper backups
# See: docs/disaster-recovery/glass-key-creation.md
```

## Calendar Integration

Add reminders to your calendar:

### Monthly Verification

**Title**: Glass-Key Monthly Verification
**Date**: 1st of every month
**Duration**: 30 minutes
**Reminder**: 1 day before
**Recurrence**: Monthly
**Checklist**: Verify bundles, checksums, USB accessibility

### Quarterly Update

**Title**: Glass-Key Quarterly Update
**Date**: January 1, April 1, July 1, October 1
**Duration**: 2 hours
**Reminder**: 1 week before
**Recurrence**: Quarterly
**Checklist**: Create new bundle, update USB, review physical backups

### Annual Recovery Test

**Title**: Glass-Key ANNUAL RECOVERY TEST (CRITICAL)
**Date**: January 1 (or your chosen date)
**Duration**: Full day (8 hours)
**Reminder**: 2 weeks before
**Recurrence**: Yearly
**Priority**: High
**Checklist**: Full recovery test, audit all locations, update docs

## Automation Opportunities

### Automated (Can Implement)

```bash
# Monthly bundle verification
# Create systemd timer to verify bundles
# Alert if verification fails

# Quarterly backup reminder
# Email/notification 1 week before due date

# Backup age warning
# Alert if latest backup >4 months old
```

### Manual (Cannot Automate)

- Physical backup inspection (requires hands-on)
- Recovery testing (requires judgment)
- Location accessibility verification (requires travel)
- Paper/metal degradation check (requires eyes)
- Estate executor communication (requires human interaction)

### Future Enhancements

Not currently implemented, but could be:

```nix
# modules/services/backup/glass-key-automation.nix
systemd.timers.glass-key-monthly-verify = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnCalendar = "monthly";
    Persistent = true;
  };
};

systemd.services.glass-key-monthly-verify = {
  script = ''
    # Mount USB, verify bundles, send notification
  '';
};
```

## Maintenance Log

Keep a log of all maintenance activities:

**Format** (offline document):
```
Glass-Key Maintenance Log
═══════════════════════════════════════════════════════════════

YYYY-MM-DD | Monthly Verification
- Bundles verified: ✓
- Checksums verified: ✓
- USB accessible: ✓
- Issues: None
- Performed by: [Name]

YYYY-MM-DD | Quarterly Update
- New bundle created: ✓
- USB updated: ✓
- Old backups deleted: ✓
- Paper backups inspected: ✓
- Issues: None
- Performed by: [Name]

YYYY-MM-DD | Annual Recovery Test
- VM test completed: ✓
- Recovery time: X hours
- All locations verified: ✓
- Documentation updated: ✓
- Issues: [List any]
- Next test scheduled: YYYY-MM-DD
- Performed by: [Name]

YYYY-MM-DD | Major Change Update
- Trigger: New host added (hostname)
- New bundle created: ✓
- USB updated: ✓
- Master key changed: No
- Performed by: [Name]
```

## Checklist for Complete Maintenance

Annual review - verify all maintenance tasks complete:

- [ ] **Monthly tasks**: Completed 12/12 months this year
- [ ] **Quarterly tasks**: Completed 4/4 quarters this year
- [ ] **Annual test**: Completed and documented
- [ ] **Physical audit**: All locations verified accessible
- [ ] **Documentation**: All guides reviewed and updated
- [ ] **Executor contact**: Confirmed executor has current info
- [ ] **Backup inventory**: Updated with current state
- [ ] **Issues log**: All issues documented and resolved
- [ ] **Next year scheduled**: All tasks scheduled for next year

## Consequences of Skipped Maintenance

Understanding why each task matters:

### Skip Monthly Verification

**Risk**: Won't know if USB backup is corrupted until disaster
**Impact**: Hours/days lost during recovery finding working backup
**Mitigation**: Takes 15 minutes, just do it

### Skip Quarterly Update

**Risk**: Backups become stale, missing recent changes
**Impact**: Lose recent hosts, secrets, configs during recovery
**Mitigation**: Automated script makes this easy

### Skip Annual Test

**Risk**: Recovery procedure broken, won't know until disaster
**Impact**: **CRITICAL** - Could fail to recover during real disaster
**Mitigation**: This is the most important task - DO NOT SKIP

### Skip After-Change Update

**Risk**: New hosts/secrets not in backups
**Impact**: Lose recent infrastructure during recovery
**Mitigation**: Immediate update after major changes

## Responsibility Assignment

Who performs each task:

| Task | Owner | Backup |
|------|-------|--------|
| Monthly verification | You | [Alternate person] |
| Quarterly update | You | [Alternate person] |
| Annual test | You | [No substitute - too important] |
| After-change update | You | [Alternate person] |
| Documentation updates | You | N/A |

**Note**: If you're unavailable (travel, illness), ensure backup person knows how to perform monthly/quarterly tasks.

## Quick Reference Card

Print this and keep with USB backup:

```
═══════════════════════════════════════════════════════════════
                  GLASS-KEY MAINTENANCE QUICK REFERENCE
═══════════════════════════════════════════════════════════════

MONTHLY (1st of month, 15 min):
  1. Mount USB: sudo cryptsetup open /dev/sdX glass-key-backup
  2. cd /mnt/glass-key/glass-key-backup-*
  3. Verify: git bundle verify *.bundle && sha256sum -c MANIFEST.txt
  4. Unmount: sudo umount /mnt/glass-key && sudo cryptsetup close glass-key-backup

QUARTERLY (Jan/Apr/Jul/Oct 1, 2 hours):
  1. Create: cd ~/nix-config && ./scripts/create-glass-key-backup.sh
  2. Mount USB: sudo cryptsetup open /dev/sdX glass-key-backup
  3. Copy: sudo cp -r ~/glass-key-backup-* /mnt/glass-key/
  4. Verify: cd /mnt/glass-key/glass-key-backup-* && sha256sum -c MANIFEST.txt
  5. Cleanup: Delete old backups (keep latest + previous)
  6. Unmount

ANNUALLY (Jan 1, 8 hours):
  1. Full recovery test in VM
  2. Audit all backup locations
  3. Test USB encryption
  4. Update all documentation
  5. Schedule next year

AFTER MAJOR CHANGES (30 min):
  Same as quarterly update (immediate)

DOCUMENTATION:
  ~/nix-config/docs/disaster-recovery/maintenance-schedule.md
═══════════════════════════════════════════════════════════════
```

## Final Reminder

**Untested backups are not backups.**

The annual recovery test is non-negotiable. It's the only way to validate the entire disaster recovery system works. Schedule it now, block the time, and complete it every year.

Your future self (during a disaster) will thank your present self (during annual test) for ensuring recovery works.
