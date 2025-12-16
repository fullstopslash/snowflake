# Repository Backup for Disaster Recovery

## Overview

Repository backups provide offline access to your infrastructure configuration, eliminating dependency on GitHub availability. Combined with the master age key, they enable complete infrastructure rebuild without external dependencies.

## Why Repository Backups?

### Dependency Elimination

**GitHub dependencies**:
- GitHub account accessible
- GitHub.com online
- Network connectivity available
- No account lockout/suspension

**Offline bundle approach**:
- No GitHub required
- No network required (after bundle created)
- Works from USB or local storage
- Complete repository history

### Disaster Scenarios

1. **GitHub Account Loss**
   - Account suspended/locked
   - Password lost, 2FA device lost
   - Account compromised and deleted

2. **Network Unavailable**
   - Regional internet outage
   - ISP failure
   - Recovery location without connectivity
   - Network infrastructure destroyed

3. **GitHub Outage**
   - Service downtime
   - Regional CDN issues
   - DDoS attack

**Solution**: Offline git bundles on encrypted USB

## Git Bundle Format

Git bundles are self-contained repository snapshots that work without a remote:

```bash
# Create bundle
git bundle create repo.bundle --all

# Clone from bundle (just like git clone)
git clone repo.bundle repo-name

# Result: Full git repository with complete history
```

**Benefits**:
- Single file contains entire repository
- All commits, branches, tags included
- Works offline (no remote needed)
- Can be copied, backed up, encrypted

## Backup Script

The automated backup script creates a complete glass-key bundle:

**Location**: `scripts/create-glass-key-backup.sh`

**What it does**:
1. Create dated backup directory
2. Copy nix-config and nix-secrets repositories
3. Create git bundles for offline use
4. Include master age key
5. Generate recovery instructions
6. Create verification checklist
7. Generate manifest with checksums

**Usage**:
```bash
# Create backup bundle
./scripts/create-glass-key-backup.sh

# Create in specific location
./scripts/create-glass-key-backup.sh /mnt/usb/backup-20251216

# With custom master key location
./scripts/create-glass-key-backup.sh ~/backup ~/master-key.txt
```

**Output structure**:
```
glass-key-backup-20251216/
├── nix-config/              # Full repo copy
├── nix-config.bundle        # Git bundle (offline)
├── nix-secrets/             # Full repo copy
├── nix-secrets.bundle       # Git bundle (offline)
├── master-recovery-key.txt  # Age private key
├── RECOVERY.md              # Recovery instructions
├── VERIFICATION.md          # Verification checklist
└── MANIFEST.txt             # File list and checksums
```

## Creating Offline Backups

### Step 1: Generate Backup Bundle

```bash
cd ~/nix-config
./scripts/create-glass-key-backup.sh
```

**Output**:
```
Creating glass-key backup bundle...
Backing up nix-config...
Backing up nix-secrets...
Including master recovery key...
✓ Glass-key backup created: /home/rain/glass-key-backup-20251216
```

### Step 2: Verify Bundle

```bash
cd ~/glass-key-backup-20251216

# Verify git bundles are valid
git bundle verify nix-config.bundle
git bundle verify nix-secrets.bundle

# Test cloning from bundles
mkdir test
cd test
git clone ../nix-config.bundle nix-config
git clone ../nix-secrets.bundle nix-secrets

# Verify cloned repos
cd nix-config && git log -1
cd ../nix-secrets && git log -1
cd ../..
rm -rf test
```

### Step 3: Copy to USB

```bash
# Assuming USB mounted at /mnt/usb
cp -r ~/glass-key-backup-20251216 /mnt/usb/

# Verify copy
cd /mnt/usb/glass-key-backup-20251216
sha256sum -c MANIFEST.txt
```

### Step 4: Encrypt USB (Recommended)

See `glass-key-creation.md` section on USB encryption.

If USB is not encrypted:
- Physical USB security is critical
- Anyone with USB can access master key
- Store USB in fireproof safe

If USB is LUKS encrypted:
- USB can be stored less securely (still secure though)
- Passphrase required for access
- Store passphrase separately from USB

## Using Bundles for Recovery

### Scenario: GitHub Unavailable

**Traditional approach** (fails):
```bash
git clone https://github.com/user/nix-config  # ERROR: Network unavailable
```

**Bundle approach** (works):
```bash
# From USB backup
git clone /mnt/usb/glass-key-backup-20251216/nix-config.bundle nix-config
git clone /mnt/usb/glass-key-backup-20251216/nix-secrets.bundle nix-secrets

# Result: Full repositories, no network needed
```

### Bundle → Remote Workflow

After cloning from bundle, restore remote:

```bash
cd nix-config

# Current state
git remote -v
# origin  /mnt/usb/glass-key-backup-20251216/nix-config.bundle (fetch)
# origin  /mnt/usb/glass-key-backup-20251216/nix-config.bundle (push)

# Update remote to GitHub
git remote set-url origin https://github.com/user/nix-config

# Verify
git remote -v
# origin  https://github.com/user/nix-config (fetch)
# origin  https://github.com/user/nix-config (push)

# Pull latest changes (if GitHub accessible now)
git pull
```

## Bundle Updates

### Update Frequency

**Quarterly** (every 3 months):
- Normal development pace
- Captures most changes
- Balances freshness vs. effort

**After major changes**:
- New host added
- Significant refactoring
- Secret rotation
- Infrastructure redesign

**Before long absence**:
- Vacation
- Extended travel
- Planned downtime

### Update Process

```bash
# 1. Create new bundle
./scripts/create-glass-key-backup.sh

# 2. Copy to USB (new directory)
cp -r ~/glass-key-backup-$(date +%Y%m%d) /mnt/usb/

# 3. Verify new bundle
cd /mnt/usb/glass-key-backup-$(date +%Y%m%d)
git bundle verify nix-config.bundle
git bundle verify nix-secrets.bundle

# 4. Delete old bundle (keep one previous for rollback)
cd /mnt/usb
ls -t | grep glass-key-backup | tail -n +3 | xargs rm -rf

# Result: USB has current + previous backup
```

### Automated Updates

Add to `modules/services/misc/auto-upgrade.nix` (future work):

```nix
# Automatic quarterly bundle creation
systemd.timers.glass-key-backup = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnCalendar = "quarterly";  # Jan 1, Apr 1, Jul 1, Oct 1
    Persistent = true;
  };
};

systemd.services.glass-key-backup = {
  script = ''
    ${pkgs.bash}/bin/bash /home/rain/nix-config/scripts/create-glass-key-backup.sh \
      /mnt/backup/glass-key-backup-$(date +%Y%m%d)
  '';
};
```

**Not implemented yet** - manual process for now.

## Recovery Instructions File

Each bundle includes `RECOVERY.md` with complete instructions:

```markdown
# Glass-Key Disaster Recovery

## Contents
- nix-config/ - Full configuration repo
- nix-config.bundle - Git bundle (offline)
- nix-secrets/ - All encrypted secrets
- nix-secrets.bundle - Git bundle (offline)
- master-recovery-key.txt - Age key to decrypt all secrets
- RECOVERY.md - This file

## Recovery Steps

1. Install Base NixOS
2. Clone from bundles (no GitHub needed)
3. Decrypt secrets with master key
4. Bootstrap first host
5. Rebuild infrastructure

See: nix-config/docs/disaster-recovery/total-recovery.md
```

This allows recovery without external documentation.

## Verification Checklist

Each bundle includes `VERIFICATION.md`:

```markdown
# Glass-Key Backup Verification

## Before Storing
- [ ] nix-config repo copied
- [ ] nix-secrets repo copied
- [ ] Git bundles created
- [ ] Master key included
- [ ] RECOVERY.md present
- [ ] All files readable

## Test Recovery (Annually)
- [ ] Boot test VM
- [ ] Clone from bundle
- [ ] Decrypt test secret
- [ ] Bootstrap test host
- [ ] Verify all secrets accessible

## Update Schedule
- [ ] Quarterly: Update USB backup
- [ ] Annually: Test full recovery
- [ ] After major changes: Re-snapshot
- [ ] After key rotation: New bundles
```

Work through this checklist before storing backups.

## Manifest File

Each bundle includes `MANIFEST.txt`:

```
Glass-Key Backup Manifest
Created: 2025-12-16 14:30:00
Hostname: malphas
User: rain

Contents:
/path/to/nix-config.bundle 15M
/path/to/nix-secrets.bundle 2M
/path/to/master-recovery-key.txt 256
/path/to/RECOVERY.md 1K
/path/to/VERIFICATION.md 512

Checksums (SHA256):
[sha256sum of each file]

Git Status:
nix-config: a1b2c3d4e5f6... (commit hash)
nix-secrets: f6e5d4c3b2a1... (commit hash)
```

**Uses**:
- Verify bundle integrity (checksums)
- Track which git commits are in bundle
- Audit bundle contents
- Detect corruption

## Testing Bundles

### Annual Recovery Test

Perform full recovery test annually:

```bash
# 1. Boot test VM (do NOT use production)
# 2. Install minimal NixOS
nix-shell -p git age sops

# 3. Clone from bundles
git clone /mnt/usb/glass-key-backup-*/nix-config.bundle nix-config
git clone /mnt/usb/glass-key-backup-*/nix-secrets.bundle nix-secrets

# 4. Decrypt with master key
export SOPS_AGE_KEY_FILE=/mnt/usb/glass-key-backup-*/master-recovery-key.txt
sops -d nix-secrets/sops/shared.yaml

# 5. Bootstrap test host
cd nix-config
sudo SOPS_AGE_KEY_FILE=$SOPS_AGE_KEY_FILE \
  ./scripts/bootstrap-nixos.sh -n recovery-test -d /dev/vda

# 6. Verify
sudo ls /run/secrets/
systemctl status
```

Document results in `.planning/phases/17-physical-security/recovery-test-YYYY-MM-DD.md`.

### Quick Verification

Monthly quick check:

```bash
# Verify bundles are valid
cd /mnt/usb/glass-key-backup-*/
git bundle verify nix-config.bundle
git bundle verify nix-secrets.bundle

# Verify checksums
sha256sum -c MANIFEST.txt

# If all pass: bundle is intact
```

## Bundle Size Management

### Typical Sizes

- nix-config bundle: 10-20 MB (with full history)
- nix-secrets bundle: 1-5 MB (with full history)
- master-recovery-key.txt: 256 bytes
- Documentation: < 1 MB
- **Total**: ~15-30 MB per bundle

### Storage Capacity

**32GB USB drive**:
- ~1000 bundles (if kept forever)
- ~100+ years at quarterly updates
- Practically unlimited

**Cleanup strategy**:
- Keep current bundle
- Keep previous bundle (rollback)
- Delete bundles older than 1 year
- Keep one annual snapshot for historical reference

## Security Considerations

### Bundle Contains

- Full configuration (public, safe to share)
- Encrypted secrets (safe without key)
- Master age key (CRITICAL - can decrypt everything)

**Threat model**:
- Attacker with bundle + master key = full compromise
- Attacker with bundle only = no secrets accessible
- Attacker with master key only = no configs to decrypt

**Mitigation**:
- Encrypt USB with LUKS (bundle + key together)
- Store USB in fireproof safe
- Never upload bundle to cloud
- Physical security paramount

### Bundle vs. GitHub

**Bundle advantages**:
- Offline access
- No account dependency
- Complete history
- Fast local clone

**GitHub advantages**:
- Automatic backups
- Accessible from anywhere
- Collaboration
- Issue tracking

**Best practice**: Use both
- GitHub for normal operation
- Bundles for disaster recovery

## Integration with Other Backups

### Glass-Key Complete Set

1. **Master age key** (paper/metal/USB)
2. **Repository bundles** (USB)
3. **Recovery instructions** (paper/USB)

All three required for complete recovery.

### Backup Relationships

```
Paper backup       → Master age key only
Metal backup       → Master age key only
USB backup         → Master key + bundles + instructions
GitHub             → Configs + encrypted secrets
nix-secrets repo   → Encrypted secrets
Bootstrap script   → Uses master key to deploy
```

**Recovery path**:
1. USB backup → clone bundles → get configs
2. Paper backup → master key → decrypt secrets
3. Bootstrap → deploy infrastructure

## Maintenance Schedule

See `maintenance-schedule.md` for complete schedule.

**Summary**:
- **Monthly**: Quick bundle verification (checksums, git bundle verify)
- **Quarterly**: Create new bundle, update USB
- **Annually**: Full recovery test, verify all backup locations
- **After major changes**: Immediate new bundle

## Next Steps

1. Run backup script: `./scripts/create-glass-key-backup.sh`
2. Test bundle cloning: Clone from bundle in test environment
3. Set up recovery procedure: `total-recovery.md`
4. Schedule maintenance: `maintenance-schedule.md`

## Troubleshooting

### Bundle verification fails

```
error: bad bundle signature
```

**Cause**: Corrupted bundle file
**Fix**: Re-create bundle from source repository

### Bundle clone fails

```
fatal: not a git bundle
```

**Cause**: Incomplete copy, corruption
**Fix**: Verify USB filesystem, re-copy bundle, check checksums

### Bundle is outdated

**Symptom**: Bundle from 2 years ago, many commits missing
**Fix**: Create new bundle with current commits

**Prevention**: Quarterly updates

### Cannot find master key in bundle

**Symptom**: Bundle has repos but no master-recovery-key.txt
**Cause**: Master key not copied by script, or user error
**Fix**:
1. If master key exists elsewhere: Copy to bundle
2. If master key lost: See `master-key-setup.md` troubleshooting

## Checklist

Before considering repository backup complete:

- [ ] Backup script created and tested
- [ ] Git bundles verified (git bundle verify)
- [ ] Bundle cloning tested
- [ ] Master key included in bundle
- [ ] Recovery instructions in bundle
- [ ] Verification checklist in bundle
- [ ] Manifest with checksums created
- [ ] USB backup created and encrypted
- [ ] Quarterly update scheduled
- [ ] Annual test scheduled

## References

- Git bundle documentation: `man git-bundle`
- Backup script: `scripts/create-glass-key-backup.sh`
- Total recovery guide: `total-recovery.md`
- Master key setup: `master-key-setup.md`
