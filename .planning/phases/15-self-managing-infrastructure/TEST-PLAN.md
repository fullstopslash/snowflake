# Phase 15 Multi-Host Auto-Update Testing Plan

## Test Environment

**Test VMs**: sorrow and torment
- Minimal headless VMs configured for GitOps testing
- Auto-upgrade enabled with hourly schedule
- Golden generation rollback enabled
- Build validation and safety checks configured

## Test Scenarios

### 1. Single Host Auto-Upgrade Workflow

**Objective**: Verify basic auto-upgrade functionality on one VM

**Test Steps**:
1. SSH into sorrow VM
2. Check current system generation: `sudo nix-env --list-generations --profile /nix/var/nix/profiles/system`
3. Make a trivial change to nix-config (add comment)
4. Commit and push change
5. Trigger manual upgrade: `sudo systemctl start nix-local-upgrade.service`
6. Monitor upgrade: `sudo journalctl -fu nix-local-upgrade.service`
7. Verify new generation created
8. Verify services still running: `systemctl status sshd tailscaled`

**Expected Result**: System upgrades successfully, new generation activated

### 2. Build Validation and Rollback

**Objective**: Test that broken configurations are rejected and rolled back

**Test Steps**:
1. SSH into sorrow VM
2. Check current commit: `cd ~/nix-config && git log -1`
3. Inject build error (syntax error in configuration)
4. Commit and push broken config
5. Trigger upgrade: `sudo systemctl start nix-local-upgrade.service`
6. Monitor logs: `sudo journalctl -fu nix-local-upgrade.service`
7. Verify build failed and git was rolled back
8. Check commit: `cd ~/nix-config && git log -1`
9. Verify system is still on old generation

**Expected Result**:
- Build fails with clear error message
- Git automatically rolls back to previous commit
- System remains on working generation
- Service continues to run normally

### 3. Validation Check Failure

**Objective**: Test custom validation checks and failure handling

**Test Steps**:
1. Add a validation check that will fail
2. Modify sorrow config to add: `validationChecks = [ "false" ];`
3. Rebuild and restart sorrow VM
4. Make trivial change and trigger upgrade
5. Monitor upgrade process
6. Verify validation fails and rollback occurs

**Expected Result**:
- Validation check fails
- Git rolls back due to `onValidationFailure = "rollback"`
- System stays on current generation

### 4. Golden Generation Boot Safety

**Objective**: Test boot failure detection and automatic rollback

**Test Steps**:
1. Pin current generation as golden: `sudo golden-pin-current`
2. Verify golden gen: `ls -la /nix/var/nix/gcroots/golden-generation`
3. Create config that breaks boot (disable sshd)
4. Deploy broken config manually
5. Reboot VM
6. Wait for boot timeout and automatic rollback
7. Verify system rolled back to golden generation
8. Verify SSH accessible again

**Expected Result**:
- Boot fails validation (sshd not active)
- After 2 failed attempts, system rolls back to golden
- System boots successfully on golden generation
- SSH access restored

### 5. Multi-Host Concurrent Updates

**Objective**: Test simultaneous upgrades on multiple hosts

**Test Steps**:
1. SSH into both sorrow and torment
2. Check current generations on both
3. Make configuration change (affects both hosts)
4. Commit and push
5. Trigger upgrade on both VMs simultaneously:
   - Terminal 1: `ssh sorrow sudo systemctl start nix-local-upgrade.service`
   - Terminal 2: `ssh torment sudo systemctl start nix-local-upgrade.service`
6. Monitor both upgrades in parallel
7. Verify both complete successfully
8. Check both are on same generation
9. Verify no conflicts in git

**Expected Result**:
- Both hosts pull same commit
- Both build and switch successfully
- No git conflicts (read-only pull)
- Both end up on identical configurations

### 6. Network Failure Graceful Degradation

**Objective**: Test behavior when git pull fails

**Test Steps**:
1. SSH into sorrow
2. Block network access: `sudo iptables -A OUTPUT -j DROP`
3. Trigger upgrade: `sudo systemctl start nix-local-upgrade.service`
4. Monitor logs
5. Restore network: `sudo iptables -F`
6. Verify system still functional

**Expected Result**:
- Git pull fails with network error
- Upgrade aborts gracefully
- No rollback needed (git unchanged)
- System remains functional

### 7. Pre-Update Hooks

**Objective**: Test custom pre-update hooks execute before pull

**Test Steps**:
1. Add pre-update hook to sorrow config:
   ```nix
   preUpdateHooks = [
     "${pkgs.coreutils}/bin/touch /tmp/pre-update-ran"
     "${pkgs.coreutils}/bin/date > /tmp/pre-update-timestamp"
   ];
   ```
2. Rebuild sorrow
3. Remove test files: `sudo rm -f /tmp/pre-update-*`
4. Trigger upgrade
5. Check files created: `ls -la /tmp/pre-update-*`

**Expected Result**:
- Hook services run before upgrade
- Test files created with correct content
- Upgrade proceeds normally after hooks

### 8. Hourly Auto-Upgrade Schedule

**Objective**: Verify automated scheduled upgrades work

**Test Steps**:
1. Check upgrade timer status: `systemctl status nix-local-upgrade.timer`
2. Check next scheduled run: `systemctl list-timers nix-local-upgrade.timer`
3. Make config change and push
4. Wait for next scheduled run (max 1 hour)
5. Monitor automatic upgrade
6. Verify new generation activated

**Expected Result**:
- Timer fires on schedule
- Upgrade runs automatically
- No manual intervention needed

## Test Matrix

| Test | Sorrow | Torment | Expected Result |
|------|--------|---------|----------------|
| 1. Basic upgrade | ✓ | - | Success |
| 2. Build failure rollback | ✓ | - | Rollback |
| 3. Validation failure | ✓ | - | Rollback |
| 4. Boot failure rollback | ✓ | - | Golden restore |
| 5. Concurrent upgrades | ✓ | ✓ | Both succeed |
| 6. Network failure | ✓ | - | Graceful abort |
| 7. Pre-update hooks | ✓ | - | Hooks execute |
| 8. Scheduled upgrade | ✓ | - | Auto-runs |

## Success Criteria

- [ ] All 8 test scenarios pass
- [ ] No data loss during rollbacks
- [ ] Systems remain accessible after failures
- [ ] Git state correctly tracked and restored
- [ ] Logs clearly show what happened
- [ ] Multi-host testing shows no conflicts

## Notes

- Tests should be run in order (1-8)
- Some tests are destructive (require VM restart)
- All tests should be repeatable
- Document any unexpected behavior
- Take snapshots before destructive tests

## Commands Reference

**Check upgrade status**:
```bash
sudo systemctl status nix-local-upgrade.service
sudo journalctl -fu nix-local-upgrade.service
```

**Manual trigger**:
```bash
sudo systemctl start nix-local-upgrade.service
```

**Check generations**:
```bash
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

**Golden generation**:
```bash
sudo golden-pin-current
sudo golden-show
ls -la /nix/var/nix/gcroots/golden-generation
```

**Git state**:
```bash
cd ~/nix-config && git log -1
cd ~/nix-secrets && git log -1
```
