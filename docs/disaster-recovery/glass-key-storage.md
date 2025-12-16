# Glass-Key Storage Strategy

## Overview

Proper storage of glass-key backups is critical. The storage strategy must balance two opposing requirements:

1. **Security**: Prevent unauthorized access to master key
2. **Accessibility**: Enable recovery when needed

This guide provides a practical storage strategy for homelab environments.

## Core Principles

### Geographic Diversity

**Never store all backups in one location.**

Scenarios that destroy a single location:
- House fire
- Flood
- Tornado/hurricane
- Burglary
- Building collapse

**Minimum**: 3 copies in 3 different locations

### Access Control

**Only you should have direct access to master key.**

Acceptable storage:
- Personal safe in your home
- Safety deposit box in your name
- Sealed envelope with trusted executor

Unacceptable storage:
- Shared family safe (others have access)
- Workplace (employer might access)
- Friend's house (unsealed)
- Public locker

### Environmental Protection

**Backups must survive common disasters.**

Protection required:
- Fire (fireproof safe or naturally fire-resistant metal)
- Water (laminated paper, waterproof container, or metal)
- Physical damage (rigid container, not loose in drawer)
- Degradation (archival materials, periodic replacement)

### Security Levels

Different backup formats have different security/accessibility trade-offs:

| Format | Security | Accessibility | Update Frequency |
|--------|----------|---------------|------------------|
| Paper (home safe) | Medium | High (immediate) | Quarterly |
| Paper (off-site) | High | Medium (1-2 days) | Annually |
| Metal (off-site) | Highest | Low (bank hours) | Rarely |
| USB (home safe) | Medium | High (immediate) | Quarterly |

## Recommended Storage Configurations

### Configuration 1: Minimal (3 Locations)

**Best for**: Single person, limited budget, starting point

1. **Home Fireproof Safe** (Quick Access)
   - Contents: Paper backup (laminated) + USB backup (encrypted)
   - Access time: Immediate
   - Purpose: Fast recovery from most scenarios

2. **Bank Safety Deposit Box** (Secure Off-Site)
   - Contents: Paper backup (laminated)
   - Access time: Bank business hours
   - Purpose: Fire/flood protection, geographic diversity

3. **Trusted Person** (Emergency Backup)
   - Contents: Sealed envelope with paper backup
   - Access time: Coordinate with person (days)
   - Purpose: Final fallback if other locations inaccessible

**Total cost**: ~$50-100/year (safety deposit box fee)

### Configuration 2: Robust (4 Locations)

**Best for**: Critical infrastructure, higher security needs

1. **Home Fireproof Safe** (Quick Access)
   - Contents: Paper backup + USB backup (quarterly updated)
   - Access time: Immediate
   - Purpose: Fast recovery

2. **Bank Safety Deposit Box #1** (Secure Off-Site)
   - Contents: Metal backup (long-term)
   - Access time: Bank hours
   - Purpose: Fire-resistant, long-term storage

3. **Bank Safety Deposit Box #2** (Geographic Diversity)
   - Contents: Paper backup
   - Location: Different bank, different city if possible
   - Access time: Bank hours
   - Purpose: Protection from localized disasters

4. **Attorney/Executor** (Estate Planning)
   - Contents: Sealed envelope with recovery instructions
   - Access time: Coordinate or after death
   - Purpose: Estate recovery, final backup

**Total cost**: ~$150-300/year (two safety deposit boxes)

### Configuration 3: Paranoid (5+ Locations)

**Best for**: Critical infrastructure, high-value secrets, estate planning

Add to Configuration 2:

5. **Second Home Safe** (Different Building)
   - Location: Vacation property, parent's house, etc.
   - Contents: Paper backup

6. **Safety Deposit Box in Different State**
   - For protection from regional disasters
   - Contents: Metal backup

**Total cost**: ~$300-500/year

## Storage Location Details

### Home Fireproof Safe

**Requirements**:
- UL-rated for document protection (not just fire-resistant)
- Bolt to floor (prevent theft of entire safe)
- Water-resistant gasket
- Size: Minimum 0.5 cubic feet

**What to store**:
- Paper backup (Copy 1)
- USB encrypted backup
- Recovery instructions quick reference card

**Pros**:
- Immediate access
- No access restrictions
- No recurring fees

**Cons**:
- Vulnerable to home disasters (fire/flood)
- Vulnerable to burglary if not bolted
- No off-site protection

**Recommended safes**:
- SentrySafe SFW123GDC (fire + water, ~$200)
- First Alert 2087F (fireproof, ~$100)
- Honeywell 1114 (fire + water, ~$150)

### Bank Safety Deposit Box

**Requirements**:
- Reputable bank (FDIC insured)
- Individual box (not joint access unless spouse needs access)
- Size: Smallest (3x5) is sufficient
- Insurance: Bank coverage + your homeowner's insurance

**What to store**:
- Paper backup (Copy 2) in sealed envelope
- Metal backup (if using)
- Printed recovery instructions

**Pros**:
- High security (bank vault)
- Fire/flood/disaster protection
- Off-site (geographic diversity)
- Insurance coverage

**Cons**:
- Business hours access only
- Annual fee ($50-200)
- Bank could fail or relocate
- Requires ID to access

**Tips**:
- Label envelope: "Emergency Recovery Keys - [Your Name]"
- Don't seal metal backup (shows you have nothing to hide)
- Seal paper backup (prevents casual viewing)
- Visit annually to verify contents

### Trusted Person (Sealed Envelope)

**Requirements**:
- Trusted family member or close friend
- Different geographic location
- Understands importance (won't lose it)
- Contact information documented

**What to store**:
- Paper backup in sealed envelope
- Label: "Emergency Infrastructure Recovery - Open Only If Requested"
- Your contact information on outside

**Instructions to person**:
```
This envelope contains emergency recovery information for my
infrastructure. Please store it securely and do not open unless:

1. I explicitly request it, OR
2. I am deceased and executor requests it

Storage requirements:
- Keep sealed
- Store in safe or secure location
- Do not digitize or photograph
- Contact me annually to confirm you still have it

Thank you for being my backup plan.
```

**Pros**:
- Free
- Off-site protection
- Geographic diversity
- Estate planning integration

**Cons**:
- Depends on person's reliability
- They could open it (trust required)
- Might be lost during their move/life changes
- Not immediately accessible

**Best candidates**:
- Sibling in different state
- Parent with secure home storage
- Close friend who understands tech
- Attorney (if willing to store documents)

### Safety Deposit Box (Second Location)

**When to use**: Configuration 2 or 3, for geographic diversity

**Requirements**:
- Different bank than primary
- Different city (50+ miles away) if possible
- Same security requirements as primary

**What to store**:
- Paper backup OR metal backup
- Minimal contents (cost efficiency)

**Purpose**:
- Protection from localized disasters (earthquake, hurricane)
- Redundancy if primary bank fails
- Additional fallback

## Geographic Diversity Strategy

### Local Disaster Protection

**Scenario**: House fire, local flooding

**Requirement**: At least one off-site backup within 1-hour drive

**Implementation**:
- Primary: Home safe
- Secondary: Bank safety deposit box in same city
- Result: Fire/flood at home → recover from bank

### Regional Disaster Protection

**Scenario**: Hurricane, earthquake, regional power outage

**Requirement**: At least one backup 50+ miles away

**Implementation**:
- Primary: Home safe
- Secondary: Bank safety deposit box (same city)
- Tertiary: Trusted person in different state
- Result: Regional disaster → recover from trusted person

### Catastrophic Disaster Protection

**Scenario**: You relocate, lose access to all local resources

**Requirement**: Backup accessible from anywhere

**Implementation**:
- Metal backup in safety deposit box (survives long-term)
- Trusted person with sealed envelope (can ship to you)
- Result: Start new life in new location → still have recovery access

## Access Time Planning

Plan for different recovery time windows:

### Immediate Access (0-1 hour)
- **Location**: Home safe
- **Scenario**: Test recovery, local rebuild
- **Contents**: Paper + USB

### Same-Day Access (1-24 hours)
- **Location**: Local safety deposit box
- **Scenario**: Home disaster, quick recovery needed
- **Contents**: Paper or metal

### Multi-Day Access (2-7 days)
- **Location**: Trusted person, second safety deposit box
- **Scenario**: Regional disaster, coordinated recovery
- **Contents**: Paper backup

### Long-Term Access (1+ months)
- **Location**: Attorney, estate executor
- **Scenario**: Estate planning, extended unavailability
- **Contents**: Recovery instructions + paper backup

## Security Threats and Mitigations

### Threat: Burglary

**Risk**: Thief steals home safe

**Mitigation**:
- Bolt safe to floor (prevent safe theft)
- Safe hidden in closet (not obvious)
- Off-site backups remain secure
- Paper is useless without technical knowledge

**Assessment**: Low risk (burglar unlikely to know what age key is)

### Threat: Physical Compromise

**Risk**: Someone gains access to master key

**Mitigation**:
- Sealed envelopes show tampering
- Multiple locations (compromise of one doesn't expose all)
- Trust relationships (limited to few people)
- Regular verification (check seals annually)

**Assessment**: Medium risk (depends on trust relationships)

### Threat: Digital Exposure

**Risk**: You accidentally digitize backup (photo, scan, etc.)

**Mitigation**:
- Clear documentation: "NEVER digitize"
- Physical-only workflow
- No exceptions policy
- Training for executors

**Assessment**: High risk (user error most common threat)

### Threat: Loss Through Neglect

**Risk**: Storage location forgotten, backups decay

**Mitigation**:
- Document all locations offline
- Annual verification (check each location)
- Maintenance schedule (replace degraded backups)
- Calendar reminders

**Assessment**: High risk (most common failure mode)

### Threat: Destruction of All Copies

**Risk**: Catastrophic loss of all backup locations simultaneously

**Mitigation**:
- Geographic diversity (different cities/states)
- Multiple formats (paper, metal, USB)
- Periodic verification (ensure copies exist)
- Future: Shamir secret sharing (3-of-5 reconstruction)

**Assessment**: Very low risk (requires multiple simultaneous disasters)

## Documentation of Storage Locations

**CRITICAL**: Document where backups are stored.

**Where to document**:
- Offline notebook (not digital)
- Password manager (encrypted, locations only, not the keys)
- Estate planning documents (for executor)

**What to document**:
```
Glass-Key Backup Locations:

Copy 1 (Paper + USB):
  Location: Home office safe (behind bookshelf)
  Safe combo: [if applicable]
  Last verified: 2025-12-16
  Next update: 2026-03-16 (quarterly)

Copy 2 (Paper):
  Location: First National Bank, Safety Deposit Box #456
  Access: [Your name], ID required
  Last verified: 2025-12-16
  Next update: 2026-12-16 (annual)

Copy 3 (Paper, sealed):
  Location: [Trusted person name], [city/state]
  Contact: [phone/email]
  Instructions: "Emergency Recovery Keys" envelope
  Last verified: 2025-12-16
  Next contact: 2026-12-16 (annual)

Copy 4 (Metal):
  Location: Second bank, different city
  Last verified: 2025-12-16
  Next update: 2030-12-16 (rare, only if key rotated)
```

**Where NOT to document**:
- In git repositories (especially nix-config)
- Cloud notes (defeats offline purpose)
- Unencrypted text files
- Email

## Estate Planning Integration

### Why It Matters

If you're incapacitated or deceased, someone needs to access your infrastructure (or at least know it exists).

### Executor Instructions

Create a document for your executor:

```
Infrastructure Recovery (For Executor)

IF I am deceased or incapacitated:

1. Locate glass-key backups:
   - Home safe: [location]
   - Safety deposit box: [bank name], Box [number]
   - Trusted person: [name and contact]

2. Contents:
   - Master age key (can decrypt all secrets)
   - Recovery instructions
   - Infrastructure documentation

3. Recovery options:
   - Rebuild infrastructure (follow recovery instructions)
   - OR decrypt critical data (passwords, documents)
   - OR securely destroy (if not needed)

4. Security:
   - Do NOT digitize the master key
   - Do NOT upload to cloud
   - Follow recovery instructions exactly

5. Contact:
   - Technical contact: [trusted tech friend]
   - They can help with recovery process

6. After recovery:
   - Securely destroy all physical backups
   - Shred paper, destroy USB, melt metal
```

### Legal Documents

Include in will or trust:

- Existence of infrastructure backups
- Location of glass-key storage documentation
- Instructions for executor
- Technical contact for assistance

## Verification Schedule

### Quarterly (Every 3 Months)

- [ ] Update USB backup with latest configs
- [ ] Verify home safe contents
- [ ] Test USB encryption/decryption
- [ ] Update git bundles on USB

### Annually (Every 12 Months)

- [ ] Verify ALL backup locations
- [ ] Check paper for fading/degradation
- [ ] Verify bank safety deposit box contents
- [ ] Contact trusted person to confirm they still have envelope
- [ ] Check metal backup for corrosion (if accessible)
- [ ] Perform full recovery test
- [ ] Update executor documentation if needed

### After Major Changes

- [ ] Infrastructure redesign → update backups
- [ ] Master key rotation → create NEW backups, destroy OLD
- [ ] Move locations → update documentation
- [ ] Change executor → update estate documents

## Next Steps

1. Implement backup creation: `glass-key-creation.md`
2. Set up repository backups: `repo-backup.md`
3. Test recovery: `total-recovery.md`
4. Schedule maintenance: `maintenance-schedule.md`

## Checklist

Before considering storage strategy complete:

- [ ] At least 3 backup locations identified
- [ ] Geographic diversity (not all in same building)
- [ ] At least one off-site location secured
- [ ] Home safe purchased and bolted (if using)
- [ ] Safety deposit box rented (if using)
- [ ] Trusted person identified and contacted
- [ ] Storage locations documented offline
- [ ] Executor instructions created
- [ ] Annual verification scheduled
- [ ] Quarterly USB update scheduled

## Final Security Reminder

The master key on these backups is the most sensitive secret in your infrastructure. It can decrypt:
- All passwords
- All API tokens
- All certificates
- All secrets for all hosts

Physical security is paramount. Multiple locations provide redundancy. Annual verification prevents loss through neglect.

**If you can't commit to this storage discipline, don't create glass-key backups.**

Consider alternatives:
- Cloud-based secret management (lose sovereignty)
- Shorter key rotation (more maintenance)
- Shamir secret sharing (split key, need 3 of 5 to recover)
