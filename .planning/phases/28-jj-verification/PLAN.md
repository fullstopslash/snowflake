# Phase 28: JJ-First System Verification and Optimization

**Objective**: Thoroughly verify and optimize the jj-first automation system across all repositories (nix-config, chezmoi, nix-secrets) to ensure flawless GitOps workflow with zero data loss.

**Status**: Planning
**Priority**: CRITICAL
**Risk Level**: HIGH (system-wide automation changes)

---

## Executive Summary

Verify that the recently implemented jj-first automation system works flawlessly across all three repositories (nix-config, chezmoi dotfiles, nix-secrets) for both manual (`just rebuild`) and automated (systemd auto-update) workflows. This is CRITICAL because:

1. **Data loss is unacceptable** - all local changes must be preserved
2. **Chezmoi must sync FIRST** - prevents dotfile overwrites
3. **nix-secrets is sensitive** - re-keying affects entire repo, rollbacks are dangerous
4. **jj must handle all merges** - seamless parallel commit handling
5. **Both systems must be normalized** - manual and auto-update use same logic

---

## Critical Requirements

### 1. All Repos Use JJ
- ✅ nix-config uses jj for all VCS operations
- ✅ chezmoi dotfiles use jj for all VCS operations
- ✅ nix-secrets uses jj for all VCS operations
- ✅ Automatic jj initialization (`jj git init --colocate`)
- ✅ Falls back to git gracefully if jj unavailable

### 2. Correct Ordering
- ✅ Chezmoi commits FIRST (before main repo deploy)
- ✅ Main repo commits SECOND
- ✅ nix-secrets updates THIRD
- ✅ Service dependencies enforce ordering

### 3. GitOps Workflow
Each repo must:
1. Commit local changes (if any exist)
2. Fetch upstream changes
3. Auto-merge using jj (conflict-free for parallel commits)
4. Push back to remote
5. Only commit when changes actually exist

### 4. Data Loss Prevention
- ✅ Zero data loss in all scenarios
- ✅ Local changes always preserved
- ✅ Rollback available on failures
- ✅ nix-secrets re-keying tracked properly
- ✅ No accidental overwrites

### 5. System Normalization
- ⚠️ **TO VERIFY**: Can `just rebuild` trigger systemd service?
- ⚠️ **TO VERIFY**: Both systems use identical jj logic
- ⚠️ **TO VERIFY**: Maintenance cost reduced by code reuse

---

## PHASE 0: CODE CONSOLIDATION (PREREQUISITE)

**Priority**: CRITICAL - Must complete BEFORE verification
**Estimated Time**: 2-3 hours
**Risk**: LOW (simplifies codebase)

### Objective

Consolidate `just rebuild` to trigger systemd service directly, eliminating code duplication between manual and automated workflows.

### Current State (Duplicated Code)

**Manual rebuild path:**
```bash
just rebuild
  ↓
scripts/rebuild-smart.sh
  ↓
scripts/rebuild-smart-helpers.sh (jj logic here)
```

**Automated update path:**
```bash
systemd timer triggers
  ↓
nix-local-upgrade.service
  ↓
auto-upgrade.nix script (jj logic here)
```

**Problem**: Two separate implementations of jj workflow = 2x maintenance, divergence risk

### Target State (Consolidated)

**Both paths use same code:**
```bash
just rebuild
  ↓
systemctl start nix-local-upgrade.service
  ↓
auto-upgrade.nix (SINGLE jj implementation)
```

**Benefits:**
- ✅ Zero code duplication
- ✅ Guaranteed identical behavior
- ✅ 50%+ reduction in maintenance cost
- ✅ Single source of truth
- ✅ Simpler verification (one code path instead of two)

### Implementation Tasks

**Task 0.1: Update justfile (15 min)**
```nix
# Before
rebuild *FLAGS:
  #!/usr/bin/env bash
  set -euo pipefail
  scripts/rebuild-smart.sh {{FLAGS}}

# After
rebuild *FLAGS:
  #!/usr/bin/env bash
  # Trigger systemd service directly
  sudo systemctl start nix-local-upgrade.service
  # Follow logs in real-time
  journalctl -fu nix-local-upgrade.service --since "1 minute ago"
```

**Task 0.2: Add flag support to service (1 hour)**

Modify `auto-upgrade.nix` to accept flags via environment:
```nix
systemd.services.nix-local-upgrade = {
  # Accept flags via environment variable
  environment = {
    REBUILD_FLAGS = "\${REBUILD_FLAGS:-}";
  };

  script = ''
    # Parse REBUILD_FLAGS
    SKIP_UPDATE=false
    SKIP_UPSTREAM=false
    SKIP_DOTFILES=false

    for flag in $REBUILD_FLAGS; do
      case "$flag" in
        --skip-update) SKIP_UPDATE=true ;;
        --skip-upstream) SKIP_UPSTREAM=true ;;
        --skip-dotfiles) SKIP_DOTFILES=true ;;
      esac
    done

    # Use flags in workflow...
  '';
};
```

**Task 0.3: Create wrapper for flags (30 min)**
```bash
# In justfile
rebuild *FLAGS:
  #!/usr/bin/env bash
  export REBUILD_FLAGS="{{FLAGS}}"
  sudo systemctl start nix-local-upgrade.service
  journalctl -fu nix-local-upgrade.service --since "1 minute ago"

rebuild-update:
  @just rebuild --update

rebuild-offline:
  @just rebuild --skip-upstream --skip-dotfiles
```

**Task 0.4: Remove duplicate scripts (15 min)**
```bash
# Delete obsolete files
rm scripts/rebuild-smart.sh
rm scripts/rebuild-smart-helpers.sh

# Keep only:
# - scripts/vcs-helpers.sh (shared helpers)
# - modules/common/auto-upgrade.nix (canonical implementation)
```

**Task 0.5: Update documentation (30 min)**
- Update README to reflect new architecture
- Document that `just rebuild` triggers systemd
- Update troubleshooting guides
- Note that logs are in journalctl

**Task 0.6: Test consolidation (30 min)**
```bash
# Test all rebuild variants work
just rebuild --dry-run
just rebuild --skip-update
just rebuild-update
just rebuild-offline

# Verify they all trigger systemd service
# Verify flags are passed correctly
# Verify logs are visible
```

### Success Criteria for Phase 0

- ✅ `just rebuild` triggers `nix-local-upgrade.service`
- ✅ All flags work (--skip-update, --offline, etc.)
- ✅ Real-time log following works
- ✅ `scripts/rebuild-smart*.sh` deleted
- ✅ Only ONE jj implementation exists
- ✅ Manual testing confirms identical behavior

### Verification After Consolidation

After Phase 0 completes, verification becomes MUCH simpler:
- Only need to verify systemd service (not two code paths)
- Agent count can be reduced (less code to audit)
- Test scenarios reduced (no need to test both paths)
- Estimated verification time: 12 hours (was 17 hours)

---

## Verification Plan

### Phase 1: Code Audit (Agent Panel)

**Agent 1: VCS Logic Auditor**
- Review all jj command usage across codebase
- Verify jj is preferred over git everywhere
- Check for any remaining `git pull/push/merge` commands
- Verify jj initialization logic
- Check auto-merge implementation

**Files to audit:**
- `modules/common/auto-upgrade.nix`
- `modules/services/dotfiles/chezmoi-sync.nix`
- `scripts/rebuild-smart.sh`
- `scripts/rebuild-smart-helpers.sh`
- `scripts/vcs-helpers.sh`

**Agent 2: Ordering Auditor**
- Verify systemd service dependencies
- Check script execution order
- Verify chezmoi runs BEFORE main repo
- Check nix-secrets ordering
- Verify Phase 3 (dotfiles) before Phase 8 (main repo commits)

**Files to audit:**
- `modules/common/auto-upgrade.nix` (service dependencies)
- `modules/services/dotfiles/chezmoi-sync.nix` (before= directives)
- `scripts/rebuild-smart-helpers.sh` (phase ordering)

**Agent 3: Data Safety Auditor**
- Check for any destructive operations
- Verify change detection before commits
- Check rollback mechanisms
- Verify conflict handling
- Check for race conditions

**Agent 4: Normalization Auditor**
- Compare manual rebuild vs auto-update logic
- Identify code duplication
- Verify both use same jj functions
- Check if manual rebuild can trigger systemd service
- Recommend consolidation opportunities

---

### Phase 2: Static Analysis

**Test 1: Grep for Anti-Patterns**
```bash
# Find any remaining git operations that should be jj
grep -r "git pull\|git push\|git merge\|git rebase" modules/ scripts/ | grep -v ".md\|#"

# Find any operations without change detection
grep -r "jj describe\|jj commit" scripts/ modules/ | grep -v "diff --quiet"

# Find any missing jj initialization
grep -r "jj git fetch" scripts/ modules/ | grep -v "jj git init"
```

**Test 2: Service Dependency Graph**
```bash
# Verify service ordering
systemctl list-dependencies nix-local-upgrade.service
systemctl list-dependencies chezmoi-pre-update.service

# Expected: chezmoi-pre-update → nix-local-upgrade
```

**Test 3: Code Coverage**
```bash
# Check all repos are handled
grep -r "nix-config\|chezmoi\|nix-secrets" modules/common/auto-upgrade.nix

# Verify all three repos use jj
```

---

### Phase 3: Functional Testing (Multi-Agent)

**Test Suite 1: Single Repo Testing**

**Agent A: Test nix-config repo**
1. Make local changes to nix-config
2. Trigger `just rebuild --dry-run`
3. Verify jj commands shown
4. Run actual rebuild
5. Verify changes committed with datever
6. Verify jj auto-merge works
7. Verify push succeeds
8. Check for data loss

**Agent B: Test chezmoi repo**
1. Make local changes to dotfiles
2. Trigger chezmoi sync
3. Verify jj commands used
4. Verify datever commit
5. Verify changes pushed
6. Verify ordering (happens before main repo)
7. Check for data loss

**Agent C: Test nix-secrets repo**
1. Make local changes to secrets
2. Trigger auto-update or manual rebuild
3. Verify jj commands used
4. Verify datever commit
5. Verify no accidental rollbacks
6. Verify re-keying events tracked
7. Check for data loss

**Test Suite 2: Multi-Repo Integration**

**Agent D: Test full manual rebuild**
1. Make changes in all 3 repos simultaneously
2. Run `just rebuild`
3. Verify execution order: chezmoi → main → secrets
4. Verify all 3 repos committed with datever
5. Verify all 3 repos pushed
6. Verify no data loss in any repo
7. Check jj log for correct merge history

**Agent E: Test auto-update service**
1. Make changes in all 3 repos
2. Trigger `systemctl start nix-local-upgrade.service`
3. Verify chezmoi-pre-update runs FIRST
4. Verify service ordering via logs
5. Verify all 3 repos sync correctly
6. Verify datever commits
7. Check for data loss

**Test Suite 3: Parallel Commit Testing**

**Agent F: Test parallel commits (nix-config)**
1. Make change on host A
2. Make different change on host B (same repo)
3. Run rebuild on host A
4. Verify jj auto-merge handles parallel commits
5. Run rebuild on host B
6. Verify both changes present
7. Verify no conflicts
8. Check for data loss

**Agent G: Test parallel commits (chezmoi)**
1. Make dotfile change on host A
2. Make different dotfile change on host B
3. Run rebuild on host A
4. Verify jj auto-merge in chezmoi repo
5. Run rebuild on host B
6. Verify both changes present
7. Check for data loss

**Agent H: Test parallel commits (nix-secrets)**
1. Make secret change on host A
2. Make different secret change on host B
3. Run rebuild on host A
4. Verify jj auto-merge
5. Run rebuild on host B
6. Verify both changes present
7. **CRITICAL**: Verify re-keying doesn't conflict
8. Check for data loss

**Test Suite 4: Edge Cases**

**Agent I: Test conflict scenarios**
1. Create ACTUAL file conflicts (same file, same line)
2. Trigger rebuild
3. Verify conflict detection works
4. Verify clear error messages
5. Verify rollback available
6. Manually resolve and retry
7. Verify resolution works

**Agent J: Test network failure**
1. Disable network
2. Trigger rebuild
3. Verify offline mode works
4. Verify changes committed locally
5. Re-enable network
6. Verify push succeeds on next rebuild
7. Check for data loss

**Agent K: Test fresh host initialization**
1. Deploy to new host (no prior jj repos)
2. Trigger first rebuild
3. Verify jj initialization for all 3 repos
4. Verify nix-secrets re-keying
5. Verify initial commits
6. Verify pushes succeed
7. Check for data loss

---

### Phase 4: Security & Data Integrity

**Agent L: nix-secrets Re-keying Audit**
1. Trace re-keying workflow
2. Verify jj tracking of re-key commits
3. Verify no rollback risk after re-key
4. Verify merge handling with re-key events
5. Test scenario: Host A re-keys, Host B has uncommitted secrets
6. Verify conflict resolution doesn't lose keys
7. **CRITICAL**: Verify encrypted data integrity

**Agent M: Rollback Safety Audit**
1. Verify rollback mechanisms in all scripts
2. Test rollback after failed rebuild
3. Test rollback after failed push
4. Verify state files updated correctly
5. Verify no orphaned commits
6. Check jj reflog for recovery options

---

### Phase 5: Optimization Analysis

**Agent N: Code Consolidation Review**
1. Compare `rebuild-smart-helpers.sh` vs `auto-upgrade.nix`
2. Identify duplicate jj logic
3. Recommend shared helper functions
4. Analyze if `just rebuild` can trigger systemd service
5. Estimate maintenance cost reduction

**Potential optimization:**
```bash
# Current: Two separate implementations
# - rebuild-smart-helpers.sh (manual)
# - auto-upgrade.nix (systemd)

# Proposed: Unified approach
# - just rebuild → systemctl start nix-local-upgrade.service
# - Reduces code duplication
# - Guarantees identical behavior
# - Lower maintenance cost
```

**Agent O: Performance Analysis**
1. Measure rebuild time with jj vs git
2. Measure auto-merge overhead
3. Identify bottlenecks
4. Recommend optimizations
5. Verify datever commit overhead is minimal

---

### Phase 6: Cross-Verification

**Panel Discussion: All Agents**
1. Each agent presents findings
2. Cross-validate results
3. Identify conflicting observations
4. Reach consensus on issues
5. Prioritize fixes
6. Approve system or request changes

**Success Criteria:**
- ✅ All 3 repos use jj correctly
- ✅ Ordering verified (chezmoi → main → secrets)
- ✅ Zero data loss in all tests
- ✅ Parallel commits merge automatically
- ✅ nix-secrets re-keying safe
- ✅ Manual and auto-update normalized
- ✅ No anti-patterns detected
- ✅ Edge cases handled
- ✅ Security verified

**Failure Criteria:**
- ❌ Any data loss detected
- ❌ Wrong ordering observed
- ❌ git operations instead of jj
- ❌ Missing change detection
- ❌ Rollback mechanism broken
- ❌ Re-keying conflicts
- ❌ Race conditions

---

## Implementation Tasks

### Task 0: Code Consolidation (PREREQUISITE - 2-3 hours)
**Must complete BEFORE verification begins**
- Update justfile to trigger systemd service
- Add flag support to auto-upgrade.nix
- Delete scripts/rebuild-smart*.sh
- Test consolidated system
- Update documentation

### Task 1: Deploy Agent Panel (3 hours)
- Spawn 15 specialized agents
- Assign verification tasks
- Coordinate execution
- Collect results

### Task 2: Execute Verification Tests (6 hours)
- Run all test suites
- Document results
- Capture evidence (logs, screenshots)
- Record any failures

### Task 3: Cross-Verification (2 hours)
- Agent panel discussion
- Consensus building
- Issue prioritization
- Final verification report

### Task 4: Optimization Implementation (4 hours)
- Consolidate code if recommended
- Implement `just rebuild` → systemd trigger
- Reduce maintenance cost
- Re-test after changes

### Task 5: Documentation (2 hours)
- Document verified behavior
- Update user guides
- Create troubleshooting guides
- Document recovery procedures

**Total Estimated Time: 17 hours**

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Data loss during testing | LOW | CRITICAL | Test on VMs first, backups |
| nix-secrets re-key conflict | MEDIUM | CRITICAL | Extensive re-key testing |
| Service ordering wrong | LOW | HIGH | Static analysis + runtime verify |
| jj auto-merge fails | LOW | MEDIUM | Conflict detection + rollback |
| Code duplication issues | HIGH | MEDIUM | Consolidation in optimization phase |
| Network failure handling | MEDIUM | LOW | Offline mode testing |

---

## Deliverables

1. **Verification Report** - Comprehensive test results from all agents
2. **Issue Log** - Any problems found with severity ratings
3. **Fix Recommendations** - Prioritized list of required changes
4. **Optimization Plan** - Code consolidation and systemd integration
5. **Final Approval** - Go/No-Go decision for production deployment
6. **Documentation** - User guides and troubleshooting
7. **Recovery Procedures** - Rollback and disaster recovery docs

---

## Success Metrics

- **100% jj coverage** - All repos use jj, zero git operations
- **0 data loss events** - Across all test scenarios
- **Correct ordering** - 100% of tests show chezmoi → main → secrets
- **Auto-merge success** - 95%+ parallel commits merge without intervention
- **Code consolidation** - 50%+ reduction in duplicate logic
- **Maintenance cost** - 40%+ reduction via normalization
- **Security verified** - nix-secrets re-keying tested and safe

---

## Next Steps

1. **Review this plan** with user for approval
2. **Spawn agent panel** (15 specialized agents)
3. **Execute Phase 1** (Code Audit)
4. **Execute Phase 2** (Static Analysis)
5. **Execute Phase 3** (Functional Testing)
6. **Execute Phase 4** (Security & Data Integrity)
7. **Execute Phase 5** (Optimization Analysis)
8. **Execute Phase 6** (Cross-Verification)
9. **Deliver results** and recommendations
10. **Implement fixes** if needed
11. **Final approval** for production

---

## Open Questions

1. Should `just rebuild` directly trigger systemd service? (reduces maintenance)
2. What's acceptable auto-merge success rate? (target: 95%+)
3. How to handle nix-secrets re-key during active development?
4. Should we add pre-commit hooks to prevent non-jj commits?
5. What's the rollback time limit for nix-secrets? (prevent stale rollbacks)

---

## Appendix A: Test Scenarios

**Scenario Matrix:**
- 3 repos × 3 operations (commit, fetch, merge) = 9 base scenarios
- × 2 modes (manual, auto) = 18 scenarios
- × 3 edge cases (conflicts, network fail, fresh host) = 54 scenarios
- × 3 data safety tests = 162 total test cases

**Agent Assignment:**
- Agents A-C: Single repo (9 scenarios each = 27 total)
- Agents D-E: Multi-repo (18 scenarios each = 36 total)
- Agents F-H: Parallel commits (27 scenarios)
- Agents I-K: Edge cases (27 scenarios)
- Agents L-M: Security (27 scenarios)
- Agents N-O: Optimization (18 scenarios)

**Total: 162 test scenarios across 15 agents**

---

## Appendix B: Recovery Procedures

**If data loss detected:**
1. STOP all testing immediately
2. Document exact scenario
3. Capture repo state (jj log, git log)
4. Restore from backup
5. Analyze root cause
6. Fix issue
7. Re-test scenario
8. Document in issue log

**If re-keying conflict:**
1. Isolate affected secrets
2. Verify key integrity
3. Manual merge if needed
4. Test decryption of all secrets
5. Document conflict resolution
6. Update re-key procedure

**If ordering wrong:**
1. Check systemd service logs
2. Verify service dependencies
3. Fix dependency graph
4. Test with systemctl list-dependencies
5. Re-run ordering tests
6. Document fix

---

**Status: READY FOR EXECUTION**
**Approval Required: YES**
**Estimated Completion: 17 hours with 15-agent panel**
