# Phase Plan: Auto-Update Verification on Griefling VM

**Phase ID**: auto-update-verification
**Created**: 2026-01-06
**Status**: Ready for execution
**Priority**: High

## Objective

Verify that the auto-update system works correctly on griefling VM after recent infrastructure changes, including:
- flake.lock push fix in vm-fresh recipe
- Cache override configuration for VMs (10.0.2.2)
- Auto-upgrade module configuration pointing to main branch

## Success Criteria

- [ ] Griefling VM boots successfully
- [ ] Auto-upgrade service pulls latest changes from main branch
- [ ] System rebuild completes without errors
- [ ] Cache resolver detects and uses waterbug cache via 10.0.2.2 proxy
- [ ] All systemd services (github-repos-init, deploy-chezmoi-config, chezmoi-init) complete successfully
- [ ] Any discovered issues are fixed and committed to repo

## Implementation Steps

### Step 1: Start Griefling VM
**Goal**: Boot the existing griefling VM and verify basic functionality

**Actions**:
1. Start the VM using the start-vm script
   ```bash
   ./scripts/start-vm.sh griefling
   ```
2. Wait for VM to boot (30-60 seconds)
3. Verify SSH access
   ```bash
   ssh -p 22222 rain@127.0.0.1
   ```

**Verification**:
- SSH connection succeeds
- System is responsive

**Potential Issues**:
- VM failed to start → Check if another instance is running, check disk image exists
- SSH timeout → Check if port 22222 is already in use

---

### Step 2: Monitor Auto-Upgrade Timer/Service
**Goal**: Verify auto-upgrade systemd timer is active and scheduled

**Actions**:
1. Check auto-upgrade timer status
   ```bash
   ssh -p 22222 rain@127.0.0.1 'systemctl status auto-upgrade.timer'
   ```
2. Check when next upgrade is scheduled
   ```bash
   ssh -p 22222 rain@127.0.0.1 'systemctl list-timers auto-upgrade.timer'
   ```
3. Check auto-upgrade service configuration
   ```bash
   ssh -p 22222 rain@127.0.0.1 'systemctl cat auto-upgrade.service'
   ```

**Verification**:
- Timer is active and enabled
- Next run is scheduled
- Service configuration shows correct flake URL with `main` branch

**Potential Issues**:
- Timer not enabled → Enable with `systemctl enable auto-upgrade.timer`
- Wrong branch in flake URL → Fix in auto-upgrade module

---

### Step 3: Trigger Manual Auto-Upgrade
**Goal**: Force an immediate auto-upgrade to test the system

**Actions**:
1. Trigger auto-upgrade service manually
   ```bash
   ssh -p 22222 rain@127.0.0.1 'sudo systemctl start auto-upgrade.service'
   ```
2. Follow logs in real-time
   ```bash
   ssh -p 22222 rain@127.0.0.1 'sudo journalctl -u auto-upgrade.service -f'
   ```
3. Monitor for completion (may take 5-10 minutes)

**Verification**:
- Service pulls from main branch
- Git/jj fetch succeeds
- Nix build completes
- System switches to new configuration
- Service exits with success status

**Potential Issues**:
- Git authentication fails → Check deploy keys in SOPS
- Flake evaluation fails → Check nix-secrets reference in flake.lock
- Build fails → Check for syntax errors or missing dependencies
- SOPS decryption fails → Verify age keys are properly registered

---

### Step 4: Verify Cache Resolver Configuration
**Goal**: Ensure cache resolver detects and uses waterbug cache via VM proxy

**Actions**:
1. Check cache-resolver service status
   ```bash
   ssh -p 22222 rain@127.0.0.1 'systemctl status cache-resolver.service'
   ```
2. Check if override file exists
   ```bash
   ssh -p 22222 rain@127.0.0.1 'cat /etc/cache-resolver/waterbug-override'
   ```
3. Verify generated nix.conf
   ```bash
   ssh -p 22222 rain@127.0.0.1 'cat /run/cache-resolver/nix.conf'
   ```
4. Test cache connectivity
   ```bash
   ssh -p 22222 rain@127.0.0.1 'curl -I http://10.0.2.2:9999'
   ```

**Verification**:
- Override file contains `10.0.2.2`
- Generated nix.conf includes `http://10.0.2.2:9999/system`
- Cache server responds with HTTP 200
- Cache resolver service succeeded

**Potential Issues**:
- Override file missing → Fixed in vm-fresh, but may need manual creation for existing VMs
- Cache unreachable → Check socat proxy on host, verify waterbug.lan is running
- Wrong substituters in nix.conf → Check cache-resolver script logic

---

### Step 5: Verify Core Services
**Goal**: Ensure deployment services completed successfully

**Actions**:
1. Check github-repos-init service
   ```bash
   ssh -p 22222 rain@127.0.0.1 'systemctl status github-repos-init.service'
   ```
2. Check deploy-chezmoi-config service
   ```bash
   ssh -p 22222 rain@127.0.0.1 'systemctl status deploy-chezmoi-config.service'
   ```
3. Check chezmoi-init service
   ```bash
   ssh -p 22222 rain@127.0.0.1 'systemctl status chezmoi-init.service'
   ```
4. Verify chezmoi.yaml exists and is valid
   ```bash
   ssh -p 22222 rain@127.0.0.1 'cat ~/.config/chezmoi/chezmoi.yaml | head -20'
   ```

**Verification**:
- All services show "active (exited)" or "inactive (dead)" with success
- chezmoi.yaml is decrypted and contains template variables
- No errors in service logs

**Potential Issues**:
- deploy-chezmoi-config failed → Check SOPS_AGE_KEY_CMD, ssh-to-age availability
- chezmoi.yaml missing → Service may have failed, check logs
- Decryption errors → Verify griefling age key in nix-secrets

---

### Step 6: Test Manual Rebuild
**Goal**: Verify user can manually trigger rebuilds successfully

**Actions**:
1. Pull latest changes
   ```bash
   ssh -p 22222 rain@127.0.0.1 'cd ~/nix-config && git pull'
   ```
2. Run manual rebuild
   ```bash
   ssh -p 22222 rain@127.0.0.1 'cd ~/nix-config && nh os switch'
   ```
3. Monitor for errors or warnings

**Verification**:
- Git pull succeeds
- Build completes without errors
- System switches to new generation
- No SOPS decryption errors
- Cache is used for downloads (visible in nh output)

**Potential Issues**:
- Build failures → Check for configuration errors
- SOPS errors → Age key mismatch, rekey needed
- Cache not used → Check substituters configuration

---

### Step 7: Issue Analysis & Resolution
**Goal**: Document and fix any issues discovered during testing

**Actions**:
1. Review all logs and identify root causes
2. For each issue found:
   - Document the error message
   - Identify the affected module/service
   - Determine the fix needed
3. Create fixes in nix-config repo:
   - Update relevant modules
   - Test fixes locally if possible
   - Commit with descriptive messages
4. Push fixes to main branch
5. Re-test on griefling to verify fixes

**Verification**:
- All identified issues have documented root causes
- Fixes are committed and pushed
- Re-testing shows issues are resolved

**Common Issue Categories**:
- **SOPS/Age key issues**: Usually require rekeying secrets
- **Service failures**: Check service configuration and dependencies
- **Cache issues**: Verify network connectivity and override files
- **Git/VCS issues**: Check authentication and branch configuration

---

## Risk Assessment

**Low Risk**:
- Timer not scheduled (easy fix: systemctl enable)
- Cache not used (fallback to cache.nixos.org works)

**Medium Risk**:
- Auto-upgrade service fails (manual intervention needed)
- SOPS decryption issues (requires rekeying)

**High Risk**:
- VM fails to boot (may need fresh install)
- Cascading service failures (requires systematic debugging)

## Rollback Plan

If critical issues prevent VM operation:
1. Stop the VM: `./scripts/stop-vm.sh griefling`
2. Revert commits if needed: `jj undo` or `git revert`
3. Run fresh install: `just vm-fresh griefling`

## Dependencies

**Required Tools**:
- SSH access to griefling (port 22222)
- jj/git for version control
- journalctl for log inspection
- systemctl for service management

**Required Services Running**:
- Waterbug cache server (10.0.8.141:9999)
- Socat proxy (host forwards 10.0.2.2:9999 → waterbug.lan:9999)

## Notes

- Auto-upgrade timer default schedule: Check module configuration
- Test VM environment uses QEMU user networking (10.0.2.x subnet)
- Cache override file is critical for VM cache access
- All secrets should decrypt with griefling's age key after recent rekeying

## Next Steps After Completion

1. Document any lessons learned
2. Update auto-upgrade module if improvements identified
3. Consider adding automated health checks
4. Test on other VMs (sorrow, torment, anguish)
