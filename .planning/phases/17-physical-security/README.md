# Phase 17: Physical Security & Disaster Recovery

**Status**: PLANNED (Not Yet Implemented)
**Priority**: CRITICAL before production deployment
**Dependencies**: Phase 16 (SOPS/Age Key Management)

## Overview

This phase addresses physical security threats and disaster recovery for a homelab infrastructure. It focuses on protecting against device theft and ensuring complete infrastructure recovery from offline backups.

## Key Principles

1. **Homelab Priority**: Glass-key recovery > Zero-trust purity
2. **Self-Sovereignty**: No external dependencies for disaster recovery
3. **Defense in Depth**: Multiple security layers (encryption, rotation, backups)
4. **Tested Recovery**: Annual validation ensures procedures work
5. **Physical Security**: Offline backups in multiple secure locations

## Plans

### 17-01: LUKS Full Disk Encryption Migration

**What**: Migrate all physical hosts from unencrypted disks to LUKS encryption

**Why**: Protects age keys and secrets at rest from cold boot attacks and physical theft

**Key Features**:
- Uses existing `btrfs-luks-impermanence` disko configuration
- Password-based unlock (NO YubiKey required)
- YubiKey support as optional future enhancement
- Per-host migration plans with rollback procedures
- Tested on non-critical hosts first

**Security Properties**:
- ✅ Powered-off device = encrypted age keys
- ✅ Physical theft when off = secrets protected
- ✅ Cold boot attacks prevented
- ❌ Stolen running device = still exposed (accept risk)

**Files Created**:
- `docs/luks-migration.md` - Migration procedure
- `docs/yubikey-enrollment.md` - Optional YubiKey (future)
- Per-host migration plans

### 17-02: Device Stolen Response Runbook

**What**: Comprehensive incident response procedures for physical device compromise

**Why**: Minimize damage and exposure window when device is stolen

**Key Features**:
- < 1 hour response time target
- Step-by-step immediate actions
- Secret rotation priority matrix
- 7-day monitoring procedures
- Post-incident review template
- Printable quick reference card

**Response Timeline**:
- T+0-15min: Immediate response (disable device, gather info)
- T+15min-1h: Key rotation (remove from .sops.yaml, rekey)
- T+1h-4h: Secret rotation (Tailscale, API tokens, passwords)
- T+0-7d: Monitoring (watch for unauthorized access)
- T+7d: Post-incident review

**Files Created**:
- `docs/incident-response/device-stolen.md` - Full runbook
- `docs/incident-response/QUICK-REFERENCE.md` - Emergency card
- `docs/incident-response/incident-reports/` - Templates

### 17-03: Glass-Key Disaster Recovery System ⭐ ESSENTIAL

**What**: Complete disaster recovery from physical backups only

**Why**: Homelab sovereignty - rebuild everything without external dependencies

**Key Features**:
- **Master age key** - Decrypts ALL secrets (never stored on hosts)
- **Physical backups** - Paper, metal, encrypted USB
- **Offline bundles** - Git bundles work without GitHub
- **Tested recovery** - Annual validation
- **Quarterly updates** - Keep backups current

**Recovery Scenarios**:
- Total infrastructure loss (fire, flood)
- GitHub account compromised/deleted
- All devices stolen/destroyed
- Single point of failure

**Glass-Key Contents**:
1. Master age private key (paper + metal + USB)
2. nix-config git bundle
3. nix-secrets git bundle
4. Recovery instructions (offline)
5. Verification checklist

**Storage Strategy**:
- Location 1: Home safe (paper + USB)
- Location 2: Off-site secure (paper + metal)
- Location 3: Trusted person (sealed paper)
- NEVER: Cloud, password managers, network

**Files Created**:
- `docs/disaster-recovery/master-key-setup.md`
- `docs/disaster-recovery/glass-key-creation.md`
- `docs/disaster-recovery/total-recovery.md`
- `docs/disaster-recovery/maintenance-schedule.md`
- `scripts/create-glass-key-backup.sh`

## Security Model

### Current State (Without Phase 17)
- 🔴 **HIGH RISK** - Stolen device = full secret compromise
- Age keys stored unencrypted on disk
- No offline disaster recovery tested
- GitHub dependency for recovery

### After Phase 17 Implementation
- 🟢 **LOW RISK** - Acceptable for homelab
- Stolen powered-off device = safe (LUKS)
- Stolen running device = 1-hour response window
- Total loss = recoverable from glass keys
- No external dependencies

## Implementation Order

**Recommended sequence when ready to implement:**

1. **First: Plan 17-03 (Glass-Key Recovery)** ⭐
   - Most critical for homelab
   - Enables safe experimentation
   - No downtime required
   - Can be done immediately

2. **Second: Plan 17-02 (Response Runbook)**
   - Document procedures
   - No system changes
   - Test on paper
   - Print quick reference

3. **Third: Plan 17-01 (LUKS Migration)**
   - Requires physical access
   - 1-2 hours downtime per host
   - Test on non-critical host
   - Migrate production last

## Why This Matters

**Threat Scenarios**:

1. **Laptop Stolen from Coffee Shop**:
   - Without LUKS: Attacker extracts age key, decrypts all secrets
   - With LUKS: Disk encrypted, age key protected, secrets safe
   - Response: < 1 hour key rotation, new secrets encrypted

2. **House Fire, All Devices Lost**:
   - Without glass-key: Infrastructure lost, depends on GitHub
   - With glass-key: Retrieve off-site backup, rebuild everything
   - Recovery: 5-7 days to full infrastructure

3. **GitHub Account Compromised**:
   - Without bundles: Repos deleted, configs lost
   - With bundles: Git bundles restore full history offline
   - Recovery: Hours, not days

## Current Status

**Implemented**:
- ✅ Age key infrastructure (Phase 16)
- ✅ Key rotation scripts (Phase 16)
- ✅ VCS abstraction (Phase 16)
- ✅ Disko LUKS configs (existing)

**Not Implemented** (Phase 17):
- ❌ LUKS enabled on physical hosts
- ❌ Master age key generated
- ❌ Glass-key backups created
- ❌ Response runbook written
- ❌ Recovery procedures tested

## Next Steps (When Ready)

1. **Review Plans**: Read all three plans thoroughly
2. **Start with 17-03**: Create glass-key system first (safest)
3. **Test Recovery**: Validate procedures work before depending on them
4. **Document 17-02**: Write runbooks while fresh in mind
5. **Plan 17-01**: Schedule LUKS migration when comfortable

## Important Notes

- **No YubiKey Required**: Plans designed for password-only unlock
- **YubiKey Optional**: Can add later as enhancement
- **Homelab Focus**: Self-sovereignty over enterprise patterns
- **Tested Procedures**: Annual recovery validation required
- **Physical Security**: Safe storage for backups essential

## Questions Before Implementation

Consider these before starting Phase 17:

1. Do you have a fireproof safe for backups?
2. Do you have an off-site secure location?
3. Can you tolerate 1-2 hours downtime per host for LUKS?
4. Are you comfortable with manual key typing for recovery?
5. Will you commit to quarterly backup updates?
6. Can you perform annual recovery tests?

If yes to all: Ready to implement when you choose.

## References

- Phase 16 Plans: `.planning/phases/16-sops-key-management/`
- Disko Configs: `modules/disks/btrfs-luks-impermanence-disk.nix`
- Bootstrap Script: `scripts/bootstrap-nixos.sh`
- Current SOPS: `modules/common/sops.nix`

---

**Remember**: This is FUTURE WORK. Plans are ready when you are, but no pressure to implement immediately. The infrastructure exists, the procedures are documented, and you can tackle this when the time is right.
