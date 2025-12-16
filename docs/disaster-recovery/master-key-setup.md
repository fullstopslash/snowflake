# Master Age Key Setup for Glass-Key Recovery

## Overview

The master age key is the cornerstone of the Glass-Key disaster recovery system. It enables decryption of ALL secrets across the entire infrastructure, allowing complete rebuild from catastrophic loss.

**Critical Security Property**: This key is NEVER stored on any host. It exists only in physical glass-key backups.

## Purpose

The master age key serves as the ultimate recovery mechanism:
- Decrypt all secrets when all hosts are lost
- Bootstrap new hosts without existing infrastructure
- Recover from GitHub account loss (via offline bundles)
- Enable infrastructure rebuild with only physical backups

## Generation Process

### Prerequisites

- Secure, ideally air-gapped machine for key generation
- Access to nix-secrets repository
- `age` tool installed (`nix-shell -p age`)

### Step 1: Generate Master Key

On a secure machine (preferably air-gapped):

```bash
# Generate new master age key
age-keygen -o master-recovery-key.txt

# Output will show:
# Public key: age1[62-character-public-key]
# (Private key written to master-recovery-key.txt)
```

**Save both outputs** - you'll need the public key for `.sops.yaml`.

### Step 2: Inspect the Key

```bash
# View the private key
cat master-recovery-key.txt
# Shows: AGE-SECRET-KEY-1[rest-of-private-key]

# Extract public key again if needed
age-keygen -y master-recovery-key.txt
# Shows: age1[public-key]
```

### Step 3: Add Master Key to .sops.yaml

In your `nix-secrets` repository, edit `.sops.yaml`:

```yaml
keys:
  # Master recovery key - NEVER stored on any host
  # Can decrypt ALL secrets for total infrastructure recovery
  - &master age1[your-master-public-key-here]

  # Per-host keys (SSH-derived)
  - &malphas age1[host-key]
  - &griefling age1[host-key]
  # ... other hosts

creation_rules:
  # All secrets encrypted for master key + relevant host keys
  - path_regex: sops/.*\.yaml$
    key_groups:
      - age:
        - *master     # Master key can decrypt everything
        - *malphas
        - *griefling
        # ... other hosts as needed
```

**Key points**:
- Master key goes FIRST in the age recipients list
- Master key is included in ALL creation rules
- Host keys remain for normal operation
- Master key is ONLY for recovery scenarios

### Step 4: Rekey All Secrets

After adding master key to `.sops.yaml`, rekey all secrets to include it:

```bash
cd nix-config
just rekey
```

This re-encrypts all secrets with the master key added as a recipient.

### Step 5: Verify Master Key Decryption

Test that master key can decrypt secrets:

```bash
# Set environment to use master key
export SOPS_AGE_KEY_FILE=~/master-recovery-key.txt

# Test decryption of shared secrets
sops -d nix-secrets/sops/shared.yaml

# Test decryption of host-specific secrets
sops -d nix-secrets/sops/malphas.yaml

# Should see decrypted YAML content
```

If decryption works, the master key is correctly configured.

## Security Properties

### What the Master Key Provides

- **Total Infrastructure Recovery**: With only this key and git repos, rebuild everything
- **Zero Trust in Hosts**: Loss of all host keys = recoverable
- **Offline Recovery**: No network dependencies for secret access
- **Long-Term Resilience**: Physical backups outlast digital infrastructure

### Security Requirements

**NEVER**:
- Store on any host (not even encrypted)
- Commit to git
- Upload to cloud storage
- Put in password manager
- Store digitally in any form

**ALWAYS**:
- Keep in physical form only
- Multiple copies in secure locations
- Off-site backup (fire/flood protection)
- Test recovery procedure annually

### Master Key is a Single Point of Failure

**This is intentional**. The trade-off:
- **Risk**: If master key is compromised, ALL secrets are accessible
- **Benefit**: Can rebuild entire infrastructure from catastrophic loss

**Mitigation**:
- Physical security (fireproof safe, safety deposit box)
- Multiple secure locations (not all in one place)
- Regular testing (ensure backups are accessible and legible)
- Future enhancement: Shamir secret sharing (3-of-5 shares to reconstruct)

## Storage

After generation, immediately create physical backups:

1. **Paper Backup** (see `glass-key-creation.md`)
   - Print master key on paper
   - Laminate for water resistance
   - Store in fireproof safe

2. **Metal Backup** (see `glass-key-creation.md`)
   - Engrave on stainless steel plate
   - Fire/water/corrosion resistant
   - Off-site storage

3. **USB Backup** (see `glass-key-creation.md`)
   - LUKS encrypted USB drive
   - Contains master key + git bundles
   - Update quarterly

**Delete the digital copy** after creating physical backups.

```bash
# After physical backups are created and verified
shred -vfz -n 10 master-recovery-key.txt
```

## Rotation

Master key rotation should be **rare** and **planned**:

**When to rotate**:
- Suspected compromise
- Physical backup lost/stolen
- Every 2-5 years (preventative)

**When NOT to rotate**:
- Routine maintenance
- Host key rotation
- Adding/removing hosts

**Rotation process**:
1. Generate new master key
2. Add to `.sops.yaml` (keep old key temporarily)
3. Rekey all secrets (encrypted for both old and new)
4. Create new physical backups
5. Test new key decryption
6. Remove old key from `.sops.yaml`
7. Final rekey
8. Destroy old physical backups

## Integration with Bootstrap

During disaster recovery, the bootstrap script uses the master key:

```bash
# Set master key for bootstrap
export SOPS_AGE_KEY_FILE=/path/to/master-recovery-key.txt

# Bootstrap new host
cd nix-config
sudo SOPS_AGE_KEY_FILE=$SOPS_AGE_KEY_FILE \
  ./scripts/bootstrap-nixos.sh -n hostname -d /dev/sda

# Bootstrap will:
# 1. Generate NEW host age key
# 2. Add to .sops.yaml
# 3. Rekey secrets (still encrypted for master)
# 4. Deploy system
```

The master key allows bootstrapping without existing host keys.

## Verification Checklist

Before considering master key setup complete:

- [ ] Master age key generated on secure machine
- [ ] Public key added to `.sops.yaml` as first recipient
- [ ] All secrets rekeyed with master key included
- [ ] Master key tested decrypting shared.yaml
- [ ] Master key tested decrypting host-specific secrets
- [ ] Physical backups created (see `glass-key-creation.md`)
- [ ] Digital copy securely destroyed
- [ ] Storage locations documented offline
- [ ] Recovery procedure tested (see `total-recovery.md`)

## Next Steps

1. Create physical backups: `docs/disaster-recovery/glass-key-creation.md`
2. Set up offline repository bundles: `docs/disaster-recovery/repo-backup.md`
3. Test full recovery: `docs/disaster-recovery/total-recovery.md`
4. Establish maintenance schedule: `docs/disaster-recovery/maintenance-schedule.md`

## Troubleshooting

### Master key won't decrypt secrets

**Symptom**: `sops -d` fails with master key
**Cause**: Master key not in `.sops.yaml` when secret was encrypted
**Fix**: Add master key, rekey the specific secret file

### Multiple master keys in .sops.yaml

**Symptom**: Two master keys after rotation
**Cause**: Forgot to remove old key
**Fix**: Keep only current master key, rekey all secrets

### Lost master key physical backup

**Symptom**: Cannot locate any physical backup
**Critical**: If you still have working hosts:
1. Generate NEW master key immediately
2. Add to `.sops.yaml`
3. Rekey all secrets
4. Create new physical backups
5. Old backups are now useless (good - they were lost anyway)

If NO working hosts and NO backups: **Infrastructure is unrecoverable**. This is why multiple off-site backups are critical.

## References

- Age encryption: https://age-encryption.org/
- SOPS: https://github.com/getsops/sops
- Physical backup creation: `glass-key-creation.md`
- Total recovery procedure: `total-recovery.md`
