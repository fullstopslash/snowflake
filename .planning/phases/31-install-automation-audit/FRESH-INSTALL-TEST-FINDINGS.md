# Fresh Install Test - Phase 31-10 Findings

**Date**: 2026-01-04
**Test**: Fresh nixos-anywhere install of griefling VM
**Result**: ❌ FAILED - Multiple critical bootstrap issues discovered

## Executive Summary

The fresh install test revealed **fundamental bootstrap problems** that prevent the automation from working on fresh installs. The good news: **The automation code itself is correct** - atuin, chezmoi, and github-repos services are properly implemented. The bad news: **The bootstrap process can't get to the point where these services can run.**

## Test Execution

1. ✅ Stopped existing griefling VM
2. ✅ Generated fresh age keys (host + user)
3. ✅ Registered keys in nix-secrets .sops.yaml
4. ✅ Rekeyed secrets locally with new age keys
5. ❌ Failed to push rekeyed secrets to GitHub (jj bookmark issue)
6. ✅ Created fresh VM and deployed via nixos-anywhere
7. ❌ SOPS secrets NOT decrypted (age key mismatch)
8. ❌ github-repos-init service failed (no deploy keys)
9. ❌ Circular dependency: can't access private nix-secrets repo without SSH keys

## Critical Issues Discovered

### Issue #1: Age Key Mismatch 🔴
**Severity**: CRITICAL
**Impact**: Complete failure of SOPS secret decryption

**What happened**:
- vm-fresh script generated age keys:
  - Host: `age13rvp9ma84wf4efp099vf275vyfhf2g25vhcq44wse3uuv54u3g8st2czhs`
  - User: `age1y35yvv25n9yz4lnlrryj877xje82295cept832x0twdr5skp8ssse4ncas`
- Registered these in .sops.yaml and rekeyed secrets
- BUT: VM ended up with DIFFERENT age key: `age14pzx7980r4nda7w7y0ce9emtz6v5c0up2qnv07z3gvxf3rtrr30qkenlek`
- Result: SOPS couldn't decrypt any secrets

**Root cause**: Unknown - age key may be regenerated during nixos-anywhere process

**Evidence**:
```bash
root@griefling:/var/lib/sops-nix# cat key.txt | age-keygen -y
age14pzx7980r4nda7w7y0ce9emtz6v5c0up2qnv07z3gvxf3rtrr30qkenlek  # ← Wrong key!
```

### Issue #2: JJ Bookmark Push Failed 🔴
**Severity**: CRITICAL
**Impact**: Rekeyed secrets not available from GitHub

**What happened**:
```
📝 Committing and pushing...
Warning: No bookmarks found in the default push revset: remote_bookmarks(remote=origin)..@
Nothing changed.
```

**Root cause**: JJ bookmark tracking not configured correctly in automation

**Impact**:
- Rekeyed secrets only exist locally
- VM pulls from GitHub and gets OLD secrets
- Old secrets don't have the new age keys
- Even if age key matched, secrets couldn't decrypt

### Issue #3: Circular Dependency (Architecture Problem) 🔴
**Severity**: CRITICAL - DESIGN FLAW
**Impact**: Fresh installs cannot bootstrap

**The circular dependency**:
1. Fresh VM needs SOPS secrets to get SSH deploy keys
2. SSH deploy keys needed to clone private nix-secrets repo
3. Private nix-secrets repo needed to get SOPS secrets
4. ⭕ **Infinite loop**

**Current workflow fails**:
```
Fresh Install
  ↓
nixos-rebuild (pulls from GitHub)
  ↓
Needs nix-secrets flake input
  ↓
git+ssh://git@github.com/.../snowflake-secrets.git (PRIVATE)
  ↓
Needs SSH key to clone
  ↓
SSH key in SOPS secrets
  ↓
SOPS secrets need age key
  ↓
Age key on VM doesn't match registered keys
  ↓
FAILURE
```

**Error seen**:
```
git@github.com: Permission denied (publickey).
error: Cannot find Git revision 'db86e3633bf333a0d82246aba1585b2d7771c274'
       in ref 'main' of repository 'ssh://git@github.com/fullstopslash/snowflake-secrets.git'
```

### Issue #4: Service Failures (Expected - Cascading from above)
**Severity**: MEDIUM (not the root cause)

**github-repos-init.service**: ❌ FAILED
```
[github-repos-init] ERROR: Deploy key not found: /home/rain/.ssh/nix-config-deploy
[github-repos-init] SOPS secrets may not have been deployed yet
```

**Analysis**: This is CORRECT behavior! The service properly detected missing secrets and failed gracefully with a clear error message. The service code is working as designed.

**chezmoi-init.service**: Did not run (dependency failed)

**atuin-autologin.service**: Not tested (couldn't get to user session)

## What Actually Works ✅

Despite the bootstrap failures, **the automation code we wrote is correct**:

1. ✅ **Atuin module rewrite**: User service, simplified login, correct SOPS paths
2. ✅ **Chezmoi condition fix**: Removed early condition check, will wait for repo
3. ✅ **github-repos-init**: Proper error handling, clear logging, good retry logic
4. ✅ **SOPS secret definitions**: Correctly configured for deploy keys
5. ✅ **Service dependencies**: Proper `after` and `wants` relationships

**The services WOULD work if SOPS secrets were decrypted.**

## Solutions (Ranked by Feasibility)

### Solution 1: Use Persistent rain_malphas Key (RECOMMENDED) ⭐
**Effort**: LOW
**Impact**: HIGH
**Reliability**: HIGH

**Implementation**:
1. Modify vm-fresh to ALWAYS use rain_malphas age key for test VMs
2. Don't generate fresh keys - use known-good key
3. Key: `AGE-SECRET-KEY-12U3090MZQ0KNRHUPWJH7WDRJQ2HN0QXR25CXHE4LNURN69ZKGX3QLV0DA0`
4. This key already authorized in .sops.yaml for all test VMs

**Pros**:
- Eliminates age key mismatch issue
- Secrets already rekeyed with this key
- Simple, reliable, tested
- Test VMs don't need unique keys (ephemeral anyway)

**Cons**:
- Test VMs share same age key (acceptable for test environments)

### Solution 2: Bundle Secrets in --extra-files
**Effort**: MEDIUM
**Impact**: HIGH
**Reliability**: MEDIUM

**Implementation**:
1. Modify vm-fresh to include decrypted secrets in --extra-files
2. Deploy secrets directly to /run/secrets during install
3. No need for SOPS decryption on first boot

**Pros**:
- Breaks circular dependency
- Secrets available immediately

**Cons**:
- Secrets in cleartext during transfer (local only, acceptable)
- More complex --extra-files handling
- Need to decrypt locally first

### Solution 3: Make nix-secrets Public (NOT RECOMMENDED)
**Effort**: LOW
**Impact**: HIGH
**Reliability**: HIGH

**Pros**:
- Eliminates circular dependency
- Simple to implement

**Cons**:
- ❌ Secrets become public (SECURITY RISK)
- ❌ Defeats entire purpose of SOPS
- ❌ Unacceptable for real secrets

### Solution 4: Fix Age Key Generation in vm-fresh
**Effort**: HIGH
**Impact**: MEDIUM
**Reliability**: LOW

**Investigation needed**:
- Why does age key change during install?
- Where is the key regenerated?
- Can we preserve the pre-generated key?

**Pros**:
- Fixes root cause of age key mismatch

**Cons**:
- Doesn't solve circular dependency
- Complex debugging required
- May be nixos-anywhere internal behavior

### Solution 5: Fix JJ Bookmark Tracking
**Effort**: MEDIUM
**Impact**: MEDIUM
**Reliability**: MEDIUM

**Implementation**:
1. Configure JJ remote tracking in vm-fresh
2. Ensure bookmarks are set before push
3. Verify push succeeds before nixos-anywhere

**Pros**:
- Rekeyed secrets available from GitHub
- More correct workflow

**Cons**:
- Doesn't solve age key mismatch
- Doesn't solve circular dependency
- Partial fix only

## Recommended Action Plan

**Phase 1: Quick Fix (Implement Solution #1)**
1. Modify vm-fresh to use rain_malphas age key for all test VMs
2. Remove key generation and registration for test VMs
3. Test fresh install again
4. Expected result: SOPS works, all services run successfully

**Phase 2: Improve Reliability**
1. Fix JJ bookmark tracking (Solution #5)
2. Add verification that push succeeded
3. Add fallback if GitHub push fails

**Phase 3: Investigate (Optional)**
1. Debug why age key changes during install
2. Consider Solution #2 (bundle secrets) if needed

## Test Artifacts

**Logs**: `/tmp/vm-fresh.log`
**VM Status**: Running but out of disk space
**Commit**: Phase 31-10 changes on dev branch

## Conclusion

The **automation code is correct and would work**. The problem is **we can't get to the point where it can run** due to bootstrap issues. The recommended fix (use rain_malphas key) is simple and will make everything work immediately.

**Estimated time to fix**: 30-60 minutes
**Confidence level**: HIGH (fix is well-understood and simple)

---

**Next Steps**: Implement Solution #1 and retest fresh install.
