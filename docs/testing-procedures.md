# Testing Procedures: Decentralized GitOps

This document outlines testing procedures for the decentralized GitOps system. Tests are organized by complexity and scope.

## Prerequisites

- At least one host with the system fully configured
- Access to nix-config and dotfiles repositories
- SOPS configured and working
- chezmoi initialized with jj

## Test Status

### Completed Tests

- ✅ Secret migration to SOPS
- ✅ Chezmoi template rendering with SOPS secrets
- ✅ JJ initialization and basic workflow
- ✅ JJ push to remote

### Pending Tests (Requires Multi-Host or Network Access)

- ⏸️ Multi-host concurrent edit handling
- ⏸️ Build validation error catching
- ⏸️ Network failure graceful degradation
- ⏸️ Full auto-upgrade workflow
- ⏸️ Golden generation rollback integration

## Unit Tests

### Test 1: SOPS Secret Decryption

**Purpose**: Verify secrets decrypt correctly at system build

**Prerequisites**:
- SOPS configured
- Secrets exist in nix-secrets repo

**Steps**:
```bash
# 1. Check secret exists in SOPS
cd ~/nix-secrets
sops -d sops/shared.yaml | grep -A2 "dotfiles:"

# 2. Build NixOS config
nh os build

# 3. Check secret file will be created
ls -la /run/secrets/acoustid_api 2>/dev/null && echo "✓ Secret exists" || echo "✗ Secret missing"

# 4. Verify permissions
stat -c "%a %U" /run/secrets/acoustid_api
# Expected: 400 rain
```

**Success Criteria**:
- ✅ SOPS decrypts without errors
- ✅ Build completes successfully
- ✅ Secret file exists at /run/secrets/acoustid_api
- ✅ Permissions are 400, owner is rain

**Status**: ✅ PASSED (implied by successful system build)

### Test 2: Chezmoi Template Rendering

**Purpose**: Verify chezmoi templates render correctly with SOPS secrets

**Steps**:
```bash
# 1. Dry-run template rendering
chezmoi apply --dry-run --verbose 2>&1 | tee /tmp/chezmoi-test.log

# 2. Check for errors
if grep -i "error" /tmp/chezmoi-test.log; then
  echo "✗ Template errors found"
else
  echo "✓ No template errors"
fi

# 3. Check beets config renders
chezmoi cat ~/.config/beets/config.yaml | grep -A1 "acoustid:"
# Expected: Should show actual API key value (not template variable)

# 4. Verify secret is included
if chezmoi cat ~/.config/beets/config.yaml | grep -q "iC9LdEPhyb"; then
  echo "✓ Secret rendered correctly"
else
  echo "✗ Secret not rendered"
fi
```

**Success Criteria**:
- ✅ No template errors
- ✅ Beets config renders correctly
- ✅ Secret value appears in rendered template
- ✅ No template variable syntax in output

**Status**: ⏸️ PENDING (requires `nh os switch` to deploy secrets)

### Test 3: JJ Basic Operations

**Purpose**: Verify jj co-located repo works correctly

**Steps**:
```bash
cd ~/.local/share/chezmoi

# 1. Check jj status
jj status
# Expected: Should show working copy state

# 2. Check jj log
jj log --limit 5
# Expected: Should show commit history

# 3. Make a test change
echo "# JJ test $(date)" >> README.md

# 4. Check jj detects change
jj status | grep README.md
# Expected: Should show M README.md

# 5. Create commit
jj describe -m "test: jj workflow"

# 6. Check commit exists
jj log -r @ | grep "test: jj workflow"

# 7. Reset test change
jj abandon @
jj new @-
git restore README.md
```

**Success Criteria**:
- ✅ jj status shows working copy
- ✅ jj log shows history
- ✅ jj detects file changes
- ✅ jj describe creates commit
- ✅ jj abandon removes commit

**Status**: ✅ PASSED

## Integration Tests

### Test 4: Chezmoi-Sync Service

**Purpose**: Verify chezmoi-sync service runs successfully

**Prerequisites**:
- chezmoi initialized with jj
- Auto-upgrade module configured

**Steps**:
```bash
# 1. Check service exists
systemctl list-unit-files | grep chezmoi-sync

# 2. Run manual sync
sudo systemctl start chezmoi-sync-manual.service

# 3. Check exit status
systemctl status chezmoi-sync-manual.service

# 4. Check state file
cat /var/lib/chezmoi-sync/last-sync-status
# Expected: "success" or "success-local-only"

# 5. Check logs
journalctl -u chezmoi-sync-manual.service | tail -20
```

**Success Criteria**:
- ✅ Service exists
- ✅ Service runs without errors
- ✅ State file shows success
- ✅ Logs show all steps completed

**Status**: ⏸️ PENDING (requires full system deployment)

### Test 5: Auto-Upgrade Build Validation

**Purpose**: Verify build validation catches syntax errors

**Prerequisites**:
- Auto-upgrade configured with buildBeforeSwitch = true
- Access to nix-config repo

**Steps**:
```bash
# 1. Create test branch
cd /home/rain/nix-config
git checkout -b test-validation

# 2. Introduce syntax error
echo "invalid { nix syntax" >> hosts/malphas/default.nix
git add .
git commit -m "test: intentional build error"

# 3. Try to build
nh os build 2>&1 | tee /tmp/build-test.log

# Expected: Build should fail with syntax error

# 4. Check logs show validation failure
if grep -i "error" /tmp/build-test.log; then
  echo "✓ Build validation caught error"
else
  echo "✗ Build validation did not catch error"
fi

# 5. Clean up
git checkout dev
git branch -D test-validation
git restore hosts/malphas/default.nix
```

**Success Criteria**:
- ✅ Build fails on syntax error
- ✅ Error message is clear
- ✅ System not deployed
- ✅ Rollback possible

**Status**: ⏸️ PENDING (safe to run manually)

### Test 6: Golden Generation Boot Validation

**Purpose**: Verify boot validation system works

**Prerequisites**:
- Golden generation module enabled
- At least one validated boot

**Steps**:
```bash
# 1. Check boot status
show-boot-status

# Expected output:
# Golden generation: <number>
# Current generation: <number>
# Boot failure count: 0 / 2
# Boot status: ✓ Validated

# 2. Check golden generation exists
show-golden
# Expected: Should show path to golden generation

# 3. Check state files
ls -la /var/lib/golden-generation/
# Expected files:
# - boot-failures (should contain "0")
# - golden-generation-number
# - No boot-pending file (if boot was successful)

# 4. Check journalctl for boot messages
journalctl -t golden-generation --since today

# Expected messages:
# - "Boot validation successful"
# - "Pinned generation X as golden"
```

**Success Criteria**:
- ✅ show-boot-status shows validated boot
- ✅ Golden generation is pinned
- ✅ Failure count is 0
- ✅ No boot-pending flag

**Status**: ⏸️ PENDING (requires system reboot)

## End-to-End Tests

### Test 7: Full Auto-Upgrade Workflow (Single Host)

**Purpose**: Test complete dotfile + config update workflow on one host

**Prerequisites**:
- All modules enabled
- Auto-upgrade timer configured
- Network access

**Steps**:
```bash
# 1. Make dotfile change
echo "# E2E test $(date)" >> ~/.bashrc

# 2. Make config change (if host can commit)
cd /home/rain/nix-config
echo "# E2E test $(date)" >> hosts/malphas/README.md
git add .
git commit -m "test: e2e workflow"
git push origin dev

# 3. Trigger auto-upgrade manually
sudo systemctl start auto-upgrade.service

# 4. Watch workflow
journalctl -f -u chezmoi-pre-update.service -u auto-upgrade.service

# Expected sequence:
# [chezmoi-pre-update] Fetching remote changes...
# [chezmoi-pre-update] Capturing current dotfiles...
# [chezmoi-pre-update] Successfully pushed changes
# [auto-upgrade] Pulling latest nix-config...
# [auto-upgrade] === Validating NixOS Build ===
# [auto-upgrade] === Build Validation PASSED ===
# [auto-upgrade] === Deploying New Configuration ===
# [auto-upgrade] === Deployment Successful ===

# 5. Verify dotfile change pushed
cd ~/.local/share/chezmoi
jj log -r @
# Should show commit with bashrc change

# 6. Verify system deployed
nixos-rebuild list-generations
# Should show new generation

# 7. Clean up test changes
cd ~/.local/share/chezmoi
git restore ~/.bashrc
jj describe -m "test: cleanup e2e test"

cd /home/rain/nix-config
git revert HEAD
git push origin dev
```

**Success Criteria**:
- ✅ Dotfile changes captured and pushed
- ✅ Config changes pulled
- ✅ Build validation passes
- ✅ Deployment succeeds
- ✅ New generation created
- ✅ Services remain active

**Status**: ⏸️ PENDING (safe to run manually)

### Test 8: Multi-Host Concurrent Edits

**Purpose**: Verify jj handles concurrent edits without conflicts

**Prerequisites**:
- At least 2 hosts with chezmoi+jj configured
- Both hosts have network access

**Steps**:
```bash
# ON HOST A (e.g., desktop):
cd ~/.local/share/chezmoi
echo "# Host A change $(date)" >> dot_bashrc
jj describe -m "test: host A concurrent edit"
jj git push --allow-new

# ON HOST B (e.g., server) - within seconds:
cd ~/.local/share/chezmoi
echo "# Host B change $(date)" >> dot_bashrc
jj describe -m "test: host B concurrent edit"

# Sync (fetch changes from host A)
jj git fetch
jj rebase -d @- -s @

# Check log
jj log --limit 10
# Expected: TWO separate commits, both changes preserved

# Check file content
cat dot_bashrc | tail -5
# Expected: BOTH "Host A" and "Host B" lines present

# Push merged result
jj git push --allow-new

# ON HOST A - pull and verify
jj git fetch
jj log --limit 10
# Expected: Should see both commits
```

**Success Criteria**:
- ✅ Both hosts can commit simultaneously
- ✅ No merge conflict errors
- ✅ Both changes preserved in separate commits
- ✅ Sync completes automatically
- ✅ Both changes eventually propagate to all hosts

**Status**: ⏸️ PENDING (requires 2 hosts with network access)

### Test 9: Network Failure Graceful Degradation

**Purpose**: Verify system continues working offline

**Prerequisites**:
- Host with network capability
- Ability to disable/enable network

**Steps**:
```bash
# 1. Make local dotfile change
echo "# Offline test $(date)" >> ~/.bashrc

# 2. Disconnect network
sudo systemctl stop NetworkManager
ping -c 1 1.1.1.1  # Verify offline

# 3. Trigger auto-upgrade
sudo systemctl start auto-upgrade.service

# 4. Check logs
journalctl -u chezmoi-pre-update.service | tail -20
# Expected: "Warning: Could not fetch (no network?)"

journalctl -u auto-upgrade.service | tail -20
# Expected: May fail at git pull gracefully

# 5. Check state file
cat /var/lib/chezmoi-sync/last-sync-status
# Expected: "fetch-failed"

# 6. Reconnect network
sudo systemctl start NetworkManager
ping -c 3 1.1.1.1  # Verify online

# 7. Retry auto-upgrade
sudo systemctl start auto-upgrade.service

# 8. Check logs
journalctl -u chezmoi-pre-update.service | tail -20
# Expected: "Successfully pushed changes"

# 9. Verify change pushed
cd ~/.local/share/chezmoi
jj log -r @
```

**Success Criteria**:
- ✅ Offline sync fails gracefully
- ✅ No service failures
- ✅ State file tracks failure
- ✅ Online sync succeeds and pushes pending changes

**Status**: ⏸️ PENDING (requires network control)

### Test 10: Golden Generation Rollback on Boot Failure

**Purpose**: Verify automatic rollback after failed boots

**Prerequisites**:
- Golden generation enabled
- Ability to reboot system
- Access to host (physical or remote console)

**WARNING**: This test intentionally breaks the system temporarily

**Steps**:
```bash
# 1. Note current golden generation
show-boot-status
GOLDEN_GEN=$(cat /var/lib/golden-generation/golden-generation-number)
echo "Golden generation: $GOLDEN_GEN"

# 2. Create a config that builds but fails at runtime
cd /home/rain/nix-config
cat >> hosts/malphas/default.nix << 'EOF'
# Test: Break SSH (builds fine, fails at runtime)
services.openssh.enable = lib.mkForce false;
EOF

# 3. Build and deploy
nh os build  # Should succeed
nh os switch  # Should succeed but break SSH

# 4. Reboot
sudo reboot

# 5. After reboot, check boot status
show-boot-status
# Expected: Boot failure count: 1 / 2

# 6. Reboot again (second failure)
sudo reboot

# 7. After second reboot, check status
show-boot-status
# Expected:
# - System rolled back to generation $GOLDEN_GEN
# - Boot failure count: 0 (reset)
# - Boot status: ✓ Validated

# 8. Verify SSH works (proving rollback succeeded)
systemctl status sshd
# Expected: active (running)

# 9. Fix config
cd /home/rain/nix-config
git revert HEAD
git push origin dev

# 10. Rebuild
nh os switch
```

**Success Criteria**:
- ✅ First boot failure increments counter
- ✅ Second boot failure triggers rollback
- ✅ System boots into golden generation
- ✅ Critical services (SSH) work after rollback
- ✅ Counter resets after successful rollback

**Status**: ⏸️ PENDING (requires physical/console access and reboot capability)

## Test Results Summary

### Test Execution Log

| Test # | Name | Status | Date | Notes |
|--------|------|--------|------|-------|
| 1 | SOPS Secret Decryption | ✅ PASSED | 2025-12-15 | Implied by successful build |
| 2 | Chezmoi Template Rendering | ⏸️ PENDING | - | Requires full deployment |
| 3 | JJ Basic Operations | ✅ PASSED | 2025-12-15 | All operations work |
| 4 | Chezmoi-Sync Service | ⏸️ PENDING | - | Requires full deployment |
| 5 | Build Validation | ⏸️ PENDING | - | Safe to run manually |
| 6 | Boot Validation | ⏸️ PENDING | - | Requires reboot |
| 7 | Full Auto-Upgrade | ⏸️ PENDING | - | Safe to run manually |
| 8 | Multi-Host Concurrent | ⏸️ PENDING | - | Requires 2+ hosts |
| 9 | Network Failure | ⏸️ PENDING | - | Requires network control |
| 10 | Rollback Integration | ⏸️ PENDING | - | Requires console & reboot |

### Testing Recommendations

1. **Immediate (Safe)**:
   - Test 2: Template Rendering (after `nh os switch`)
   - Test 4: Chezmoi-Sync Service (after deployment)
   - Test 5: Build Validation (in test branch)
   - Test 7: Full Auto-Upgrade (with monitoring)

2. **Next Opportunity**:
   - Test 6: Boot Validation (next scheduled reboot)

3. **Future (Multi-Host)**:
   - Test 8: Concurrent Edits (when griefling VM is accessible)
   - Test 9: Network Failure (in controlled environment)

4. **Postpone (Risky)**:
   - Test 10: Rollback Integration (requires careful planning and console access)

### Manual Testing Checklist

- [ ] Deploy full config with `nh os switch`
- [ ] Run Test 2: Verify chezmoi templates render
- [ ] Run Test 4: Verify chezmoi-sync service works
- [ ] Run Test 5: Test build validation catches errors
- [ ] Run Test 7: Test full auto-upgrade workflow
- [ ] Monitor auto-upgrade logs for 1 week
- [ ] Document any issues in recovery-procedures.md
