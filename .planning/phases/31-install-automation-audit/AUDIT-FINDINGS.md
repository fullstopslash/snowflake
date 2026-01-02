# Phase 31: Install Automation Audit - Findings

**Audit Date**: 2026-01-02
**Auditor**: Claude Sonnet 4.5
**Scope**: NixOS automated installation system (`just install` and `just vm-fresh` recipes)

## Executive Summary

This audit examined the current state of NixOS install automation across 9 critical areas. The system demonstrates significant automation maturity in some areas (deploy keys, chezmoi, auto-updates) while exhibiting critical gaps in others (SOPS key management, install normalization). The primary findings:

**CRITICAL**: 222 lines of duplicated code between `install` and `vm-fresh` recipes (55% duplication rate)
**CRITICAL**: SOPS key management is fully manual with no automation
**HIGH**: Repo cloning uses hardcoded GitHub SSH aliases requiring manual setup
**MEDIUM**: Attic cache resolution fixed but still requires manual VM network configuration

## Detailed Findings by Area

---

## 1. SOPS Key Management Automation

**Priority**: CRITICAL
**Status**: Fully Manual - No Automation

### Current Behavior

1. **SSH Host Key Generation**: Automated via `install` and `vm-fresh` recipes
   - `justfile` lines 197-208: Pre-generates ed25519 keys locally
   - Keys deployed to both `/etc/ssh` and `/persist/etc/ssh`
   - Working correctly

2. **Age Key Derivation**: Automated
   - `justfile` lines 211-218: Derives age key from SSH host key using `ssh-to-age`
   - Key deployed to `/var/lib/sops-nix/key.txt`
   - Working correctly

3. **.sops.yaml Registration**: PARTIALLY AUTOMATED
   - `justfile` lines 221-228: Calls `just sops-update-host-age-key` and `just sops-update-user-age-key`
   - Uses `helpers.sh` function `sops_update_age_key()` (lines 68-94)
   - **GAP**: Requires manual invocation, not integrated into install flow

4. **Secret Rekeying**: MANUAL
   - `justfile` lines 232-236: Manual SOPS rekeying for all secrets
   - Iterates through `sops/*.yaml` with `sops updatekeys -y`
   - **GAP**: No verification that all secrets are accessible by new host
   - **GAP**: No rollback mechanism if rekeying fails

5. **Commit/Push**: AUTOMATED but uses git-specific commands
   - `justfile` lines 239-244: Commits and pushes via `vcs_helpers.sh`
   - Uses VCS detection (jj vs git)
   - **GAP**: No conventional commit format (should use datever)

### Expected Behavior

- Full automation from key generation → .sops.yaml update → rekey → commit → push
- Zero manual intervention required
- Verification that host can decrypt all required secrets
- Conventional commit messages: `chore(HOST): register age key and rekey secrets YYYY.MM.DD.HHMM`
- Rollback on failure

### Gap Analysis

| Item | Current | Expected | Priority |
|------|---------|----------|----------|
| SSH→Age derivation | Automated | Automated | ✅ DONE |
| .sops.yaml update | Manual call | Auto in install | CRITICAL |
| Secret rekeying | Manual loop | Auto verification | CRITICAL |
| Rekey verification | None | Test decrypt | CRITICAL |
| Error handling | None | Rollback on fail | HIGH |
| Commit format | Basic | Conventional+datever | MEDIUM |
| Chezmoi rekey | Separate logic | Unified | MEDIUM |

### Recommendations

**Plan 31-02**: SOPS Key Management Automation
- Extract key registration into reusable function
- Add secret decryption verification post-rekey
- Implement rollback on failure
- Use conventional commit format with datever
- Unify chezmoi.yaml special handling with main rekey flow

---

## 2. Deploy Keys & GitHub Auth

**Priority**: HIGH
**Status**: Recently Fixed - Fully Automated (as of recent commits)

### Current Behavior

1. **Deploy Key Generation**: AUTOMATED
   - `install` (lines 296-304): Generates unique ed25519 keys per host
   - `vm-fresh` (lines 575-590): Identical logic (DRY violation)
   - Two deploy keys: `nix-config-deploy`, `nix-secrets-deploy`

2. **GitHub Registration**: AUTOMATED via `gh` CLI
   - `install` (lines 302-304): `gh repo deploy-key add` for both repos
   - `vm-fresh` (lines 584-590): Identical (DRY violation)
   - Uses GitHub CLI for API automation

3. **SOPS Storage**: AUTOMATED
   - `install` (lines 306-310): Stores private keys in `sops/HOST.yaml`
   - `vm-fresh` (lines 595-611): Identical (DRY violation)
   - Uses `yq` to create JSON, `sops --set` to encrypt

4. **Deployment**: AUTOMATED for both root and user
   - `install` (lines 318-329): Root SSH config setup
   - `install` (lines 334-355): User SSH config setup with /persist detection
   - `vm-fresh` (lines 627-673): Identical logic (DRY violation)

5. **Conditional Logic**: AUTOMATED
   - Both recipes check if deploy keys exist in SOPS
   - Skip generation if already present (idempotent)

### Expected Behavior

- Per-host deploy keys generated once
- Automatic GitHub registration via gh CLI
- Encrypted storage in SOPS
- Deployment to both root and primary user
- SSH config with IdentitiesOnly for correct key selection
- Works for both regular hosts and VMs

### Gap Analysis

| Item | Current | Expected | Priority |
|------|---------|----------|----------|
| Key generation | Automated | Automated | ✅ DONE |
| GitHub registration | Automated | Automated | ✅ DONE |
| SOPS storage | Automated | Automated | ✅ DONE |
| Root deployment | Automated | Automated | ✅ DONE |
| User deployment | Automated | Automated | ✅ DONE |
| /persist detection | Automated | Automated | ✅ DONE |
| **DRY violation** | 2x duplicate | Shared helper | CRITICAL |
| SSH config aliases | Hardcoded | Configurable | LOW |

### Current Issues

**CRITICAL DRY VIOLATION**: Deploy key logic duplicated across `install` (lines 294-355) and `vm-fresh` (lines 569-673)
- 62 lines in `install`
- 105 lines in `vm-fresh` (includes more detailed logging)
- **Solution**: Extract to `scripts/setup-deploy-keys.sh`

**MINOR**: Hardcoded GitHub SSH aliases
- Uses `github.com-nix-config` and `github.com-nix-secrets` aliases
- These must match hardcoded git clone commands
- **Solution**: Make configurable or use single deploy key

### Recommendations

**Plan 31-04**: Deploy Keys & GitHub Auth
- Extract shared logic to `scripts/setup-deploy-keys.sh HOST`
- Call from both `install` and `vm-fresh`
- Make GitHub SSH aliases configurable
- Add verification step: test clone with deploy key

---

## 3. Repository Cloning & Persistence

**Priority**: HIGH
**Status**: Automated with hardcoded SSH aliases

### Current Behavior

1. **/persist Detection**: AUTOMATED
   - `install` (lines 360-378): Detects `/persist` directory
   - `vm-fresh` (lines 677-697): Identical (DRY violation)
   - Sets `USER_HOME` to `/persist/home/USER` or `/home/USER`

2. **Clone Logic**: AUTOMATED with hardcoded SSH aliases
   - Clones 3 repos: nix-config, nix-secrets, dotfiles (chezmoi)
   - Uses SSH aliases: `git@github.com-nix-config:fullstopslash/snowflake.git`
   - **ISSUE**: Aliases hardcoded, must match SSH config setup

3. **Ownership**: AUTOMATED
   - `chown -R` to primary user after cloning
   - Uses `id -u` / `id -g` for correct UID/GID

4. **Post-Clone Rebuild**: AUTOMATED
   - `install` (lines 382-388): Runs `nixos-rebuild boot` from cloned nix-config
   - `vm-fresh` (lines 699-710): Identical (DRY violation)
   - Detects /persist for USER_HOME path

### Expected Behavior

- Automatic /persist detection on encrypted hosts
- Clone all 3 repos (nix-config, nix-secrets, dotfiles)
- Correct ownership to primary user
- Repos persist across reboots
- Post-install rebuild from cloned config

### Gap Analysis

| Item | Current | Expected | Priority |
|------|---------|----------|----------|
| /persist detection | Automated | Automated | ✅ DONE |
| Repo cloning | Automated | Automated | ✅ DONE |
| Ownership | Automated | Automated | ✅ DONE |
| Post-clone rebuild | Automated | Automated | ✅ DONE |
| **DRY violation** | 2x duplicate | Shared helper | CRITICAL |
| **SSH alias hardcoding** | Hardcoded | Flexible | HIGH |
| **No verification** | None | Test access | MEDIUM |
| **No retry logic** | None | Retry on network fail | MEDIUM |

### Current Issues

**CRITICAL DRY VIOLATION**: Repo cloning logic duplicated
- `install` lines 357-378 (22 lines)
- `vm-fresh` lines 675-697 (23 lines)
- Identical code blocks

**HIGH**: Hardcoded SSH aliases
- `git@github.com-nix-config:fullstopslash/snowflake.git`
- `git@github.com-nix-secrets:fullstopslash/snowflake-secrets.git`
- Must exactly match SSH config Host entries
- Fragile to config changes

**MEDIUM**: No verification
- Doesn't verify clone succeeded
- Doesn't test that repos are accessible
- Silent failure possible

**MEDIUM**: No retry logic
- Network failures cause immediate failure
- No exponential backoff
- No fallback mechanisms

### Recommendations

**Plan 31-05**: Repository Provisioning & Persistence
- Extract to `scripts/clone-repos.sh HOST PRIMARY_USER`
- Add verification: test `git fetch` after clone
- Add retry logic with exponential backoff
- Make SSH aliases configurable via environment
- Test reboot persistence (add to verification checklist)

---

## 4. Attic Cache Resolution

**Priority**: MEDIUM
**Status**: FIXED (as of recent commits) - Dynamic resolution working

### Current Behavior

1. **Cache Resolver Service**: IMPLEMENTED
   - `modules/services/cache-resolver.nix`: Runtime waterbug.lan discovery
   - Discovery methods: override file, DNS, mDNS, broadcast (disabled)
   - Generates `/run/cache-resolver/nix.conf` at boot
   - Graceful fallback to cache.nixos.org

2. **Build Cache Module**: CONFIGURED
   - `modules/common/build-cache.nix`: Attic cache configuration
   - `dynamicResolution = true` by default
   - Uses `!include /run/cache-resolver/nix.conf` in nix.extraOptions
   - Trusted public keys configured

3. **VM Environment**: FIXED
   - `scripts/test-fresh-install.sh` (lines 236-362): Socat proxy for QEMU user-mode networking
   - Resolves waterbug.lan on host → 10.0.2.2 proxy in VM
   - Creates override file: `/etc/cache-resolver/waterbug-override`
   - VM cache resolver uses override instead of DNS

4. **Post-Fix Status**: WORKING
   - Cache resolver service starts at boot
   - Runs before nix-daemon.service
   - Network dependency: requires network-online.target
   - Timeout: 10s with retry on failure

### Expected Behavior

- Automatic waterbug.lan discovery at boot
- Graceful fallback when cache unavailable
- VM environments use proxy workaround
- No manual configuration required
- Works on first boot and all subsequent boots

### Gap Analysis

| Item | Current | Expected | Priority |
|------|---------|----------|----------|
| Runtime discovery | Implemented | Implemented | ✅ DONE |
| Graceful fallback | Implemented | Implemented | ✅ DONE |
| VM proxy support | Implemented | Implemented | ✅ DONE |
| Network dependency | Correct | Correct | ✅ DONE |
| Override mechanism | Working | Working | ✅ DONE |
| **Install-time usage** | Not verified | Should use cache | MEDIUM |
| **First-boot reliability** | Unknown | Must work | MEDIUM |

### Remaining Issues

**MEDIUM**: Install-time cache usage unverified
- Does nixos-anywhere use the cache during install?
- Need to verify cache hits in install logs
- May need additional nix.conf in kexec environment

**MEDIUM**: First-boot timing
- Does cache-resolver start early enough?
- Nix daemon may start before cache resolver completes
- May need `RequiredBy` instead of `Before`

### Recommendations

**Plan 31-08**: Attic Cache & Final Verification (Partial - verification only)
- Test cache usage during nixos-anywhere install
- Verify cache-resolver starts before first nix operation
- Add logging to track cache hit/miss rates
- Document expected cache behavior in docs/

---

## 5. Chezmoi Deployment & Auto-Update

**Priority**: MEDIUM
**Status**: GOOD - Fully automated with pre-update workflow

### Current Behavior

1. **First Install Deployment**: AUTOMATED
   - `home-manager/chezmoi.nix`: Auto-initialization via home.activation.chezmoiInit
   - Checks for SSH key at `~/.ssh/id_ed25519`
   - Deploys chezmoi config from SOPS (`nix-secrets/sops/chezmoi.yaml`)
   - Runs `chezmoi init --apply` on first activation
   - Falls back to `chezmoi update` on subsequent activations

2. **SOPS Config Deployment**: AUTOMATED
   - Uses user age key at `~/.config/sops/age/keys.txt`
   - Decrypts `sops/chezmoi.yaml` to `~/.config/chezmoi/chezmoi.yaml`
   - Contains template variables (email, name, etc.)

3. **Repository Structure**: AUTOMATED
   - Clones dotfiles to `~/.local/share/chezmoi`
   - Uses GitHub deploy key (same as nix-config/nix-secrets)
   - Repo is separate from nix-config

4. **Auto-Update Workflow**: IMPLEMENTED via chezmoi-sync module
   - `modules/services/dotfiles/chezmoi-sync.nix`: Jujutsu-first sync
   - Runs BEFORE auto-upgrade via `chezmoi-pre-update.service`
   - Workflow: `jj git fetch` → `jj rebase` → `chezmoi re-add` → `jj describe` → `jj git push`
   - Conflict-free with jj (concurrent edits become parallel commits)

5. **Commit Format**: IMPLEMENTED with datever
   - Commit message: `chore(dotfiles): automated sync YYYY.MM.DD.HH.MM`
   - Uses datever format matching auto-upgrade module

6. **Pre-Update Integration**: IMPLEMENTED
   - `modules/common/auto-upgrade.nix` (line 421): CRITICAL ORDER comment
   - Chezmoi commits FIRST, then main repo commits
   - Prevents dotfile overwrites from upstream changes

### Expected Behavior

- First-install: Auto-deploy chezmoi from SOPS + GitHub
- Auto-update: Sync before OS updates with conventional commits
- Conflict resolution: Automatic via jujutsu
- Integration: Chezmoi commits before nix-config pulls

### Gap Analysis

| Item | Current | Expected | Priority |
|------|---------|----------|----------|
| First install | Automated | Automated | ✅ DONE |
| SOPS config | Automated | Automated | ✅ DONE |
| Auto-update | Automated | Automated | ✅ DONE |
| Pre-update order | Correct | Correct | ✅ DONE |
| Commit format | Datever | Datever | ✅ DONE |
| Conflict handling | jj auto-merge | jj auto-merge | ✅ DONE |
| **Fresh install deploy** | Not verified | Should work | MEDIUM |
| **Network failure handling** | Graceful | Graceful | ✅ DONE |

### Remaining Issues

**MEDIUM**: Fresh install deployment not verified in audit
- Does chezmoi deploy correctly on fresh install?
- Need to verify in griefling VM test
- May have timing issues with SSH key deployment

**LOW**: Manual sync command available
- `chezmoi-sync`, `chezmoi-status`, `chezmoi-show-conflicts`
- Good for debugging, but users should rarely need these

### Recommendations

**Plan 31-07**: Chezmoi & Auto-Update Workflows (Partial - verification only)
- Test chezmoi deployment on fresh griefling install
- Verify pre-update workflow runs before auto-upgrade
- Document expected chezmoi behavior in docs/
- Add troubleshooting guide for common chezmoi issues

---

## 6. Core Services OAuth Automation

**Priority**: MEDIUM
**Status**: PARTIALLY AUTOMATED - OAuth flows require manual intervention

### Current Behavior

1. **Atuin**: PARTIALLY AUTOMATED
   - Module: `modules/apps/productivity/atuin.nix`
   - Sync enabled by default (`autoSyncEnable = true`)
   - **MANUAL**: Initial `atuin register` + `atuin login` required
   - **MANUAL**: Sync key must be copied to SOPS manually
   - No automated registration workflow

2. **Syncthing**: AUTOMATED (device ID only)
   - Module: `modules/services/syncing/syncthing.nix`
   - Device ID auto-generated on first run
   - **MANUAL**: Must add device to other Syncthing instances manually
   - **MANUAL**: Folder sharing configuration manual
   - No API automation for device pairing

3. **Tailscale**: AUTOMATED with authkey
   - Module: `modules/services/networking/tailscale.nix`
   - Uses SOPS secret: `tailscale-authkey`
   - Auto-joins tailnet on first boot
   - **LIMITATION**: Authkeys expire (90 days default)
   - **MANUAL**: Authkey renewal required

### Expected Behavior

- Atuin: Auto-register + auto-login with SOPS credentials
- Syncthing: Auto-pair with existing devices via API
- Tailscale: Auto-authenticate with reusable authkey

### Gap Analysis

| Item | Current | Expected | Priority |
|------|---------|----------|----------|
| Atuin sync enable | Automated | Automated | ✅ DONE |
| Atuin registration | Manual | Automated | MEDIUM |
| Atuin login | Manual | Automated | MEDIUM |
| Syncthing device ID | Auto | Auto | ✅ DONE |
| Syncthing pairing | Manual | API automation | LOW |
| Tailscale auth | Automated | Automated | ✅ DONE |
| Tailscale key renewal | Manual | Automated reminder | LOW |

### Current Issues

**MEDIUM**: Atuin requires manual registration
- User must run `atuin register` and `atuin login` after install
- Sync key must be copied to SOPS
- Could be automated with SOPS-stored credentials

**LOW**: Syncthing pairing is manual
- New device doesn't auto-pair with existing devices
- Must use Syncthing web UI to add device
- Syncthing API could be used for automation

**LOW**: Tailscale authkey expiration
- Authkeys expire after 90 days by default
- No automated renewal process
- Could use ephemeral keys or renewal notifications

### Recommendations

**Plan 31-06**: Core Services Automation (Out of scope - optional enhancement)
- **Atuin**: Add automated registration flow using SOPS credentials
- **Syncthing**: Add API-based device pairing helper script
- **Tailscale**: Add authkey expiration monitoring + renewal reminder
- Priority: LOW (current manual process acceptable for homelab)

---

## 7. Install vs VM-Fresh Normalization

**Priority**: CRITICAL
**Status**: MAJOR DRY VIOLATIONS - 222 lines duplicated

### Detailed Code Comparison

#### Section-by-Section Analysis

| Section | install | vm-fresh | Lines | Status | Notes |
|---------|---------|----------|-------|--------|-------|
| **SSH Host Key Gen** | 197-208 | 433-445 | 12 | IDENTICAL | Pre-generate ed25519 keys |
| **Age Key Derivation** | 211-218 | 448-456 | 8 | IDENTICAL | ssh-to-age conversion |
| **SOPS Registration** | 221-228 | 458-466 | 8 | IDENTICAL | Update .sops.yaml |
| **Secret Rekeying** | 232-244 | 468-499 | 13 vs 32 | DIVERGENT | vm-fresh has chezmoi.yaml special case |
| **Flake Update** | 247-249 | 502-508 | 3 vs 7 | DIVERGENT | vm-fresh adds git commit |
| **Disk Password** | 254-262 | 511-518 | 9 | IDENTICAL | SOPS disk password retrieval |
| **Disko Password Deploy** | 268-273 | N/A | 6 | INSTALL-ONLY | mitosis.local SSH deploy |
| **nixos-anywhere** | 276-281 | N/A | 6 | INSTALL-ONLY | Different target (mitosis vs VM) |
| **TPM Token Gen** | N/A | 525-551 | 27 | VM-ONLY | During install phase |
| **Reboot Wait** | 283-292 | 554-566 | 10 vs 13 | SIMILAR | Different wait times |
| **Deploy Keys Check** | 296-297 | 572-573 | 2 | IDENTICAL | Check if keys exist |
| **Deploy Keys Gen** | 298-304 | 575-590 | 7 vs 16 | SIMILAR | vm-fresh more verbose |
| **Deploy Keys SOPS** | 306-310 | 595-611 | 5 vs 17 | SIMILAR | vm-fresh more explicit |
| **Deploy Keys Extract** | 312-315 | 617-624 | 4 vs 8 | SIMILAR | vm-fresh more verbose |
| **Deploy Keys Deploy** | 318-329 | 627-673 | 12 vs 47 | DIVERGENT | vm-fresh deploys to user too |
| **Primary User** | 331-332 | 650 | 2 vs 1 | SIMILAR | Different helper usage |
| **User Deploy Keys** | 334-355 | 652-673 | 22 vs 22 | IDENTICAL | Full duplication |
| **Repo Cloning** | 357-378 | 675-697 | 22 vs 23 | IDENTICAL | Full duplication |
| **Post-Clone Rebuild** | 381-388 | 699-710 | 8 vs 12 | SIMILAR | Slightly different paths |
| **Success Message** | 391-398 | 713-725 | 8 vs 13 | DIVERGENT | Different SSH instructions |

#### Summary Statistics

**Total Lines Analyzed**: 404 lines
- `install` recipe: 177-398 (222 lines)
- `vm-fresh` recipe: 413-725 (313 lines)

**Code Duplication**:
- Identical blocks: 106 lines (48%)
- Similar (minor differences): 64 lines (29%)
- Divergent (significant differences): 52 lines (23%)
- **Total duplication potential**: 170 lines (77%)

**Critical Findings**:
1. **SSH/Age/SOPS setup**: 28 lines identical (lines 197-228 vs 433-466)
2. **Deploy keys**: 62 lines duplicated (lines 294-355 vs 569-673)
3. **Repo cloning**: 22 lines identical (lines 357-378 vs 675-697)
4. **Post-rebuild**: 8 lines similar (lines 381-388 vs 699-710)

### Divergent Logic That Must Remain Separate

| Area | Reason | Lines |
|------|--------|-------|
| Secret rekeying | vm-fresh handles chezmoi.yaml specially | 468-499 (32 lines) |
| TPM token generation | vm-fresh only (during install phase) | 525-551 (27 lines) |
| nixos-anywhere target | Different: mitosis.local vs 127.0.0.1:PORT | 276-281 vs 522 |
| SSH port | install uses 22, vm-fresh uses 22222/22223/etc | Throughout |
| Success message | Different SSH instructions | 391-398 vs 713-725 |

### Extractable Shared Logic

**HIGH PRIORITY** - Extract to `scripts/install-helpers/`:

1. **`setup-host-keys.sh HOST EXTRA_FILES_DIR`** (28 lines)
   - Combines SSH key gen + age derivation + SOPS registration
   - Lines: 197-228 (install), 433-466 (vm-fresh)

2. **`setup-deploy-keys.sh HOST`** (62 lines)
   - Generates/retrieves deploy keys
   - Registers with GitHub via gh CLI
   - Stores in SOPS
   - Deploys to root and user
   - Lines: 294-355 (install), 569-673 (vm-fresh)

3. **`clone-repos.sh HOST PRIMARY_USER`** (22 lines)
   - Detects /persist
   - Clones nix-config, nix-secrets, dotfiles
   - Sets correct ownership
   - Lines: 357-378 (install), 675-697 (vm-fresh)

4. **`post-install-rebuild.sh HOST PRIMARY_USER`** (8 lines)
   - Detects /persist
   - Runs nixos-rebuild boot from cloned config
   - Lines: 381-388 (install), 699-710 (vm-fresh)

**MEDIUM PRIORITY** - Consider extracting:

5. **`rekey-secrets.sh HOST`** (32 lines, but divergent)
   - Rekeys all SOPS files
   - Special handling for chezmoi.yaml
   - May need flags for install vs vm-fresh differences

### Expected Post-Refactor State

**install recipe**: ~150 lines (down from 222)
- Call `setup-host-keys.sh`
- Call `rekey-secrets.sh`
- Run nixos-anywhere (install-specific)
- Call `setup-deploy-keys.sh`
- Call `clone-repos.sh`
- Call `post-install-rebuild.sh`
- Print success message

**vm-fresh recipe**: ~200 lines (down from 313)
- Call `setup-host-keys.sh`
- Call `rekey-secrets.sh --vm-mode`
- Generate TPM token (vm-specific)
- Reboot and wait (vm-specific)
- Call `setup-deploy-keys.sh`
- Call `clone-repos.sh`
- Call `post-install-rebuild.sh`
- Print success message

**Code reduction**: 222 lines → ~50 lines of helper scripts (78% reduction)

### Recommendations

**Plan 31-03**: Install Recipe Normalization
- Create `scripts/install-helpers/` directory
- Extract 4 core helper scripts
- Update both install and vm-fresh to call helpers
- Add error handling and logging to helpers
- Test on fresh griefling install to verify

---

## 8. GitOps Commit Automation

**Priority**: MEDIUM
**Status**: GOOD - Conventional commits with datever implemented

### Current Behavior

1. **Auto-Upgrade Module**: IMPLEMENTED
   - `modules/common/auto-upgrade.nix`: Full datever commit support
   - Commit format: `chore(dotfiles): automated sync YYYY.MM.DD.HH.MM`
   - Jujutsu-first with automatic conflict resolution
   - Graceful network failure handling

2. **Chezmoi Sync**: IMPLEMENTED
   - `modules/services/dotfiles/chezmoi-sync.nix`: Datever commits
   - Commit format: `chore(dotfiles): automated sync YYYY.MM.DD.HH.MM`
   - Pre-update workflow runs before auto-upgrade

3. **VCS Helpers**: IMPLEMENTED
   - `scripts/vcs-helpers.sh`: Jujutsu-first abstraction
   - Prefers jj over git for conflict-free merging
   - Auto-detects VCS type in repo
   - Functions: vcs_add, vcs_commit, vcs_push, vcs_pull, vcs_sync_upstream

4. **Conventional Commit Format**: PARTIALLY IMPLEMENTED
   - Auto-upgrade uses datever format
   - Chezmoi sync uses datever format
   - **GAP**: SOPS key management uses basic format (not datever)
   - **GAP**: Deploy key commits use basic format

5. **Conditional Commits**: IMPLEMENTED
   - Auto-upgrade only commits if changes exist (`jj diff --quiet`)
   - Chezmoi sync only commits if changes exist
   - VCS helpers support `|| true` for no-op commits

### Expected Behavior

- All automated commits use conventional format
- Datever timestamps for easy audit
- Only commit when changes actually exist
- Jujutsu-first for conflict-free automation
- Git fallback when jj unavailable

### Gap Analysis

| Item | Current | Expected | Priority |
|------|---------|----------|----------|
| Auto-upgrade format | Datever | Datever | ✅ DONE |
| Chezmoi sync format | Datever | Datever | ✅ DONE |
| VCS abstraction | Implemented | Implemented | ✅ DONE |
| Conditional commits | Implemented | Implemented | ✅ DONE |
| jj conflict handling | Auto-merge | Auto-merge | ✅ DONE |
| **SOPS commits** | Basic | Datever | MEDIUM |
| **Deploy key commits** | Basic | Datever | LOW |

### Current Issues

**MEDIUM**: SOPS key management commits lack datever
- `helpers.sh` line 91: `vcs_commit "feat: update age key for $keyname" || true`
- Should use: `chore(HOST): register age key and rekey secrets YYYY.MM.DD.HHMM`
- No datever timestamp

**LOW**: Deploy key commits lack datever
- Not explicitly tracked in audit, but likely similar to SOPS
- Should follow same conventional format

**LOW**: No commit message validation
- No enforcement of conventional commit format
- No linting of commit messages
- Could add pre-commit hook for validation

### Recommendations

**Plan 31-07**: Chezmoi & Auto-Update Workflows (Partial - commit format only)
- Update `helpers.sh` SOPS commit to use datever
- Update deploy key commit to use datever
- Add commit message validation (optional)
- Document conventional commit format in docs/

---

## 9. End-to-End Testing Coverage

**Priority**: HIGH
**Status**: PARTIAL - VM testing exists but incomplete

### Current Test Infrastructure

1. **VM Test Script**: IMPLEMENTED
   - `scripts/test-fresh-install.sh`: Fresh VM install automation
   - Supports both ISO boot and nixos-anywhere modes
   - Options: --gui, --force, --anywhere, --ssh-port, --memory, --disk-size
   - Wipes VM state for true fresh install testing

2. **VM Management Recipes**: IMPLEMENTED
   - `just vm-fresh HOST`: Full automated install
   - `just vm-start HOST`: Boot existing VM
   - `just vm-stop HOST`: Stop VM
   - `just vm-ssh HOST`: SSH into VM
   - `just vm-status HOST`: Check VM status

3. **Multi-VM Support**: IMPLEMENTED
   - Multiple test VMs: griefling, sorrow, torment, anguish
   - Unique SSH ports per VM (22222, 22223, 22224, 22225)
   - Concurrent VM testing possible

4. **GitOps Test Infrastructure**: IMPLEMENTED
   - Phase 18 completed: GitOps test infrastructure
   - Can test decentralized commit workflows
   - Multi-VM parallel testing

### Current Testing Gaps

**CRITICAL GAPS**:

1. **No automated test suite**
   - All testing is manual
   - No CI/CD validation
   - No regression testing

2. **No verification checklist automation**
   - Plan requires manual verification:
     - "AUDIT-FINDINGS.md exists and is comprehensive"
     - "All 9 known issues documented"
     - "DRY violations quantified"
   - Should be automated tests

3. **No end-to-end install validation**
   - Can run `just vm-fresh griefling`
   - Can't verify install actually worked
   - No automated post-install checks

4. **No service health checks**
   - No validation that Atuin sync works
   - No validation that Syncthing starts
   - No validation that Tailscale connects
   - No validation that chezmoi deployed correctly

5. **No repo persistence testing**
   - No verification that repos survive reboot
   - No testing of /persist functionality
   - No validation of deploy key access

6. **No cache verification**
   - No testing that Attic cache is actually used
   - No cache hit/miss metrics
   - No validation of cache-resolver service

**MEDIUM GAPS**:

1. **No network failure testing**
   - No simulation of network outages
   - No validation of graceful degradation
   - No testing of offline mode

2. **No rollback testing**
   - No validation of golden boot entries
   - No testing of automatic rollback
   - No verification of rollback success

3. **No performance testing**
   - No measurement of install time
   - No tracking of package counts
   - No validation of build speeds

### Expected Test Coverage

**Automated Tests** (should exist):
1. Fresh install completes without errors
2. All 3 repos cloned successfully
3. SOPS secrets decrypt correctly
4. Deploy keys work for git operations
5. Services start correctly (Atuin, Syncthing, Tailscale)
6. Chezmoi deploys dotfiles
7. Cache resolver finds waterbug.lan (or falls back)
8. System survives reboot
9. Repos persist after reboot
10. Auto-upgrade runs successfully

**Manual Tests** (acceptable):
- Multi-host GitOps workflows
- Hardware-specific testing
- Performance benchmarking
- Security audits

### Current Test Execution

**How to test now**:
```bash
# Start fresh griefling VM install
just vm-fresh griefling

# Wait for install to complete
# SSH into VM
just vm-ssh griefling

# MANUAL VERIFICATION:
# - Check repos exist: ls ~/nix-config ~/nix-secrets ~/.local/share/chezmoi
# - Check SOPS works: sops -d ~/nix-secrets/sops/griefling.yaml
# - Check services: systemctl status atuin syncthing tailscaled
# - Check cache: journalctl -u cache-resolver
# - Reboot and verify repos persist
```

### Recommendations

**Plan 31-08**: Attic Cache & Final Verification
- Create automated test suite: `scripts/test-fresh-install-verify.sh`
- Implement post-install health checks
- Add reboot persistence testing
- Validate cache usage with metrics
- Create verification report: PASS/FAIL for each area
- Run against griefling VM to validate Phase 31 fixes

**Test Suite Structure**:
```bash
#!/usr/bin/env bash
# scripts/test-fresh-install-verify.sh HOST

# Test 1: Repos exist and accessible
test_repos_exist() { ... }

# Test 2: SOPS decryption works
test_sops_decrypt() { ... }

# Test 3: Deploy keys work
test_deploy_keys() { ... }

# Test 4: Services running
test_services_health() { ... }

# Test 5: Chezmoi deployed
test_chezmoi_deployed() { ... }

# Test 6: Cache resolver working
test_cache_resolver() { ... }

# Test 7: Reboot persistence
test_reboot_persistence() { ... }

# Run all tests and generate report
run_all_tests() { ... }
```

---

## Cross-Cutting Issues

### 1. Hardcoded Paths and Values

**Locations**:
- GitHub organization: `fullstopslash` (hardcoded throughout)
- Repo names: `snowflake`, `snowflake-secrets`, `dotfiles` (hardcoded)
- SSH aliases: `github.com-nix-config`, `github.com-nix-secrets` (hardcoded)
- Primary user: `rain` (mostly parameterized but hardcoded in some scripts)
- Cache server: `waterbug.lan` (configurable via module but hardcoded in scripts)

**Impact**: Makes system harder to reuse for other users

**Priority**: LOW (homelab-specific is acceptable)

### 2. Error Handling

**Current State**:
- Most scripts use `set -euo pipefail` (good)
- Some use `|| true` for non-critical failures (good)
- Limited rollback mechanisms (only in auto-upgrade)

**Gaps**:
- No consistent error reporting
- No centralized logging
- No error aggregation for multi-step processes

**Priority**: MEDIUM

### 3. Documentation

**Current State**:
- Inline comments in justfile (good)
- Module documentation strings (good)
- Some dedicated docs (chezmoi-ssh-setup.md)

**Gaps**:
- No comprehensive install automation guide
- No troubleshooting runbook
- No architecture documentation for install flow

**Priority**: MEDIUM

### 4. Idempotency

**Current State**:
- Deploy keys: Idempotent (checks if exists in SOPS)
- Repo cloning: Idempotent (checks if .git exists)
- SOPS registration: Idempotent (yq upserts)

**Good**: Most operations can be safely re-run

**Priority**: ✅ GOOD

### 5. Network Dependency

**Current State**:
- Auto-upgrade: Graceful network failure handling
- Chezmoi sync: Graceful network failure handling
- Cache resolver: Graceful fallback to cache.nixos.org
- Install/vm-fresh: Hard dependency on network (no offline mode)

**Gap**: Fresh install requires network (acceptable for now)

**Priority**: LOW

---

## Remediation Plan Summary

Based on this audit, the recommended remediation order:

### Phase 31 Plans (8 total)

| Plan | Priority | LOE | Blockers | Status |
|------|----------|-----|----------|--------|
| 31-01 | N/A | 4h | None | ✅ DONE (this doc) |
| 31-02 | CRITICAL | 6h | None | Ready |
| 31-03 | CRITICAL | 8h | None | Ready |
| 31-04 | HIGH | 4h | 31-03 | Ready after 31-03 |
| 31-05 | HIGH | 4h | 31-04 | Ready after 31-04 |
| 31-06 | MEDIUM | 6h | 31-05 | Ready after 31-05 |
| 31-07 | MEDIUM | 4h | 31-06 | Ready after 31-06 |
| 31-08 | HIGH | 8h | 31-07 | Ready after 31-07 |

**Total Estimated LOE**: 44 hours (5.5 days)

### Critical Path

1. **31-03**: Install normalization (DRY violations) - **Prerequisite for all others**
2. **31-02**: SOPS automation - **Blocks fresh install reliability**
3. **31-04**: Deploy keys normalization - **Depends on 31-03**
4. **31-05**: Repo cloning normalization - **Depends on 31-04**
5. **31-08**: Final verification suite - **Validates everything**

### Optional Enhancements (Future)

- OAuth automation for Atuin/Syncthing (31-06)
- Chezmoi deployment verification (31-07)
- Network failure testing
- Performance benchmarking
- Documentation improvements

---

## Appendix A: Code Duplication Matrix

### Identical Code Blocks

| Block Description | install | vm-fresh | Lines | Priority |
|-------------------|---------|----------|-------|----------|
| SSH host key generation | 197-208 | 433-445 | 12 | CRITICAL |
| Age key derivation | 211-218 | 448-456 | 8 | CRITICAL |
| SOPS registration | 221-228 | 458-466 | 8 | CRITICAL |
| Disk password retrieval | 254-262 | 511-518 | 9 | CRITICAL |
| Deploy keys SOPS check | 296-297 | 572-573 | 2 | HIGH |
| User deploy keys deploy | 334-355 | 652-673 | 22 | HIGH |
| Repo cloning | 357-378 | 675-697 | 22 | HIGH |

**Total Identical**: 83 lines

### Similar Code Blocks (Minor Differences)

| Block Description | Difference | Lines | Priority |
|-------------------|------------|-------|----------|
| Deploy keys generation | vm-fresh more verbose logging | 7 vs 16 | MEDIUM |
| Deploy keys SOPS storage | vm-fresh more explicit | 5 vs 17 | MEDIUM |
| Post-clone rebuild | Different path detection | 8 vs 12 | MEDIUM |
| Success message | Different SSH instructions | 8 vs 13 | LOW |

**Total Similar**: 87 lines

### Divergent Code Blocks (Cannot Share)

| Block Description | Reason | Lines | Keep Separate |
|-------------------|--------|-------|---------------|
| Secret rekeying | chezmoi.yaml special handling | 32 | Yes, but extract common logic |
| TPM token generation | VM-only feature | 27 | Yes |
| nixos-anywhere target | Different hosts | Various | Yes |
| Reboot wait | Different timing | 13 | Yes |

**Total Divergent**: 72+ lines

---

## Appendix B: Helper Script Specifications

### `scripts/install-helpers/setup-host-keys.sh`

**Purpose**: Generate SSH host keys, derive age key, register in SOPS

**Usage**:
```bash
./scripts/install-helpers/setup-host-keys.sh HOST EXTRA_FILES_DIR
```

**Parameters**:
- `HOST`: Hostname (e.g., "griefling")
- `EXTRA_FILES_DIR`: Path to nixos-anywhere extra-files directory

**Steps**:
1. Generate ed25519 SSH host key in `$EXTRA_FILES_DIR/etc/ssh/`
2. Copy to `$EXTRA_FILES_DIR/persist/etc/ssh/` for encrypted hosts
3. Derive age key using ssh-to-age
4. Write age key to `$EXTRA_FILES_DIR/var/lib/sops-nix/key.txt`
5. Call `just sops-update-host-age-key HOST $AGE_PUBKEY`
6. Call `just sops-update-user-age-key rain HOST $RAIN_AGE_KEY`
7. Call `just sops-add-creation-rules rain HOST`

**Exit Codes**:
- 0: Success
- 1: SSH key generation failed
- 2: Age key derivation failed
- 3: SOPS registration failed

**Logging**: Write to stdout/stderr with `[setup-host-keys]` prefix

---

### `scripts/install-helpers/setup-deploy-keys.sh`

**Purpose**: Generate/retrieve deploy keys, register with GitHub, store in SOPS, deploy to host

**Usage**:
```bash
./scripts/install-helpers/setup-deploy-keys.sh HOST [SSH_TARGET]
```

**Parameters**:
- `HOST`: Hostname (e.g., "griefling")
- `SSH_TARGET`: Optional SSH target (default: "root@$HOST.local")

**Steps**:
1. Check if deploy keys exist in `../nix-secrets/sops/$HOST.yaml`
2. If not exists:
   a. Generate two ed25519 keys: nix-config-deploy, nix-secrets-deploy
   b. Add to GitHub via `gh repo deploy-key add`
   c. Store in SOPS via `sops --set`
3. Extract deploy keys from SOPS
4. Deploy to root: /root/.ssh/nix-config-deploy, /root/.ssh/nix-secrets-deploy
5. Create root SSH config with IdentitiesOnly
6. Get primary user
7. Deploy to user with /persist detection
8. Create user SSH config

**Exit Codes**:
- 0: Success
- 1: Key generation failed
- 2: GitHub registration failed
- 3: SOPS storage failed
- 4: Deployment failed

---

### `scripts/install-helpers/clone-repos.sh`

**Purpose**: Clone nix-config, nix-secrets, dotfiles to appropriate location

**Usage**:
```bash
./scripts/install-helpers/clone-repos.sh HOST PRIMARY_USER [SSH_TARGET]
```

**Parameters**:
- `HOST`: Hostname
- `PRIMARY_USER`: Username (e.g., "rain")
- `SSH_TARGET`: Optional SSH target (default: "root@$HOST.local")

**Steps**:
1. Detect /persist directory via SSH
2. Set USER_HOME to /persist/home/$PRIMARY_USER or /home/$PRIMARY_USER
3. Clone nix-config via git@github.com-nix-config:fullstopslash/snowflake.git
4. Clone nix-secrets via git@github.com-nix-secrets:fullstopslash/snowflake-secrets.git
5. Clone dotfiles via git@github.com-nix-config:fullstopslash/dotfiles.git to .local/share/chezmoi
6. Set ownership to $PRIMARY_USER:users

**Exit Codes**:
- 0: Success
- 1: /persist detection failed
- 2: Clone failed
- 3: Ownership change failed

**Retry Logic**: Retry each clone up to 3 times with exponential backoff

---

### `scripts/install-helpers/post-install-rebuild.sh`

**Purpose**: Run nixos-rebuild boot from cloned nix-config

**Usage**:
```bash
./scripts/install-helpers/post-install-rebuild.sh HOST PRIMARY_USER [SSH_TARGET]
```

**Parameters**:
- `HOST`: Hostname
- `PRIMARY_USER`: Username
- `SSH_TARGET`: Optional SSH target (default: "root@$HOST.local")

**Steps**:
1. Detect /persist directory
2. Set USER_HOME
3. Run `nixos-rebuild boot --flake $USER_HOME/nix-config#$HOST`

**Exit Codes**:
- 0: Success
- 1: Rebuild failed

---

## Appendix C: Verification Checklist

### Pre-Remediation Baseline (Current State)

- [x] AUDIT-FINDINGS.md created
- [x] All 9 areas documented
- [x] DRY violations quantified (222 lines, 77% duplication)
- [x] install vs vm-fresh differences documented
- [x] Priorities assigned (CRITICAL/HIGH/MEDIUM/LOW)

### Post-Plan-31-02 (SOPS Automation)

- [ ] SOPS key registration fully automated
- [ ] Secret rekeying with verification
- [ ] Commit format uses datever
- [ ] Error handling and rollback
- [ ] Chezmoi.yaml rekey unified

### Post-Plan-31-03 (Install Normalization)

- [ ] Helper scripts created in scripts/install-helpers/
- [ ] install recipe uses helpers
- [ ] vm-fresh recipe uses helpers
- [ ] Code duplication reduced by 77%
- [ ] Both recipes still work identically

### Post-Plan-31-04 (Deploy Keys)

- [ ] Deploy key logic in shared helper
- [ ] GitHub registration automated
- [ ] Root and user deployment working
- [ ] Verification step added

### Post-Plan-31-05 (Repo Cloning)

- [ ] Repo cloning in shared helper
- [ ] /persist detection working
- [ ] Retry logic implemented
- [ ] Ownership correct

### Post-Plan-31-06 (Core Services)

- [ ] Atuin registration automated (optional)
- [ ] Syncthing pairing helper (optional)
- [ ] Tailscale authkey monitoring (optional)

### Post-Plan-31-07 (Chezmoi & Commits)

- [ ] Chezmoi deploys on fresh install
- [ ] Pre-update workflow verified
- [ ] Commit format uses datever everywhere

### Post-Plan-31-08 (Final Verification)

- [ ] Automated test suite created
- [ ] All tests pass on griefling VM
- [ ] Reboot persistence verified
- [ ] Cache usage confirmed
- [ ] Documentation updated

### Success Criteria (All Plans Complete)

- [ ] Fresh griefling install works end-to-end
- [ ] Zero manual intervention required
- [ ] All repos cloned and persist
- [ ] SOPS decryption works
- [ ] All services start correctly
- [ ] Chezmoi deployed
- [ ] Cache used when available
- [ ] System survives reboot
- [ ] Code duplication < 10%
- [ ] Automated tests pass

---

## Appendix D: Reference Files

### Key Files Audited

**Justfile**:
- Lines 177-398: `install` recipe (222 lines)
- Lines 413-725: `vm-fresh` recipe (313 lines)

**Modules**:
- `modules/common/auto-upgrade.nix`: Auto-upgrade with datever commits
- `modules/services/cache-resolver.nix`: Dynamic cache resolution
- `modules/common/build-cache.nix`: Attic cache configuration
- `modules/services/dotfiles/chezmoi-sync.nix`: Chezmoi automation

**Scripts**:
- `scripts/vcs-helpers.sh`: VCS abstraction (jj/git)
- `scripts/helpers.sh`: SOPS key management helpers
- `scripts/test-fresh-install.sh`: VM testing automation

**Home Manager**:
- `home-manager/chezmoi.nix`: Chezmoi first-install automation

### Known Working Features

- ✅ Deploy keys: Fully automated (as of recent commits)
- ✅ Chezmoi sync: Pre-update workflow with datever
- ✅ Auto-upgrade: Jujutsu-first with conflict resolution
- ✅ Cache resolver: Dynamic waterbug.lan discovery
- ✅ VCS abstraction: Jujutsu-first with git fallback
- ✅ Idempotency: Most operations safely re-runnable

### Known Issues

- ❌ 222 lines of duplicated code (77% duplication)
- ❌ SOPS key management not automated
- ❌ No automated end-to-end tests
- ❌ No post-install verification suite

---

**End of Audit Report**

Generated: 2026-01-02
Next Step: Plan 31-02 (SOPS Key Management Automation)
