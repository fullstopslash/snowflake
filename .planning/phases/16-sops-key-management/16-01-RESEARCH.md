# Research: SOPS/Age Key Management & Rotation

## Research Objective

Understand current SOPS/age implementation in this NixOS configuration to design enforcement and rotation mechanisms that align with:
- Filesystem-driven module architecture
- Role-based configuration patterns
- lib.mkDefault override system
- Explicit over implicit behavior
- Jujutsu-based version control

## Questions to Answer

### 1. Current SOPS Configuration

**Where and how is sops-nix configured?**
- Read `modules/common/sops.nix`
- Find all references to `sops.age` in the codebase
- Identify all `sops.secrets` definitions across hosts/modules
- Locate `.sops.yaml` configuration file(s)

**Key generation behavior:**
- Is `generateKey = true` used everywhere or configurable?
- Where are keys stored? (`/var/lib/sops-nix/key.txt` vs other paths)
- Are SSH host keys used as fallback recipients?
- How are keys handled on new host deployment?

### 2. Host-Specific Secret Management

**How do secrets vary by host?**
- Grep for `sops.defaultSopsFile` across all host configs
- Find pattern: per-host secret files vs shared secrets
- Check: `hosts/*/default.nix` for secret configuration
- Identify: which secrets are host-specific vs role-based

**Secret categories:**
- Find all uses of `hostSpec.secretCategories`
- Map categories to actual secret files
- Understand: base, server, network, cli, desktop categories

### 3. Current Key Distribution

**How are age public keys managed?**
- Find `.sops.yaml` location and read it
- Count: how many age recipients are defined?
- Pattern: per-host keys vs shared keys vs admin keys
- Check: are public keys committed to repo?

**Key material location:**
- Search for any age key files in repo (should be none!)
- Check: `/var/lib/sops-nix/` references
- Find: documentation about key bootstrap process

### 4. Integration Points

**Where does SOPS integrate with the system?**
- Find all systemd service dependencies on SOPS secrets
- Check: activation scripts that depend on secrets
- Identify: boot-time secret requirements
- Map: which modules require secrets at evaluation vs activation

**Module patterns:**
- How do modules declare secret dependencies?
- Pattern for making secrets available to services
- Error handling when secrets missing

### 5. Bootstrap and Deployment

**How are new hosts initialized?**
- Read `scripts/bootstrap-nixos.sh` or equivalent
- Check `docs/addnewhost.md` for key setup process
- Find: does first deploy require manual key placement?
- Understand: order of operations (key → secrets → rebuild)

**Testing infrastructure:**
- Check `tests/sops.bats` if exists
- Find: griefling VM setup for secret testing
- Understand: how secrets work in ephemeral test VMs

### 6. Pain Points and Gaps

**What's currently missing or problematic?**
- Are there TODO comments about key management?
- Check ISSUES.md or TODO.md for secret-related items
- Find: any workarounds or hacks in current implementation
- Identify: manual steps that should be automated

## Research Method

For each question:
1. Use Grep to find relevant files
2. Use Read to examine configuration
3. Document findings with file:line references
4. Note architectural patterns discovered

## Output Format

Create `16-01-FINDINGS.md` with:

### Current Architecture
- How SOPS is configured (module structure)
- Key storage locations and generation behavior
- Secret file organization pattern

### Key Lifecycle
- Bootstrap process for new hosts
- Current rotation capabilities (if any)
- Recipient management in `.sops.yaml`

### Integration Patterns
- How modules consume secrets
- Systemd dependencies on decryption
- Boot-time secret availability

### Identified Gaps
- Missing enforcement mechanisms
- Manual steps in key lifecycle
- Rotation process (exists or missing?)
- Permission/ownership checks (exists or missing?)

### Architecture Alignment
- Which patterns align with repo principles?
- What needs to change to fit filesystem-driven modules?
- How to integrate with role system and lib.mkDefault?

### Recommendations
- Module structure for enforcement (where it should live)
- Integration with existing `modules/common/sops.nix`
- Jujutsu workflow for key rotation
- Testing strategy using griefling VM
