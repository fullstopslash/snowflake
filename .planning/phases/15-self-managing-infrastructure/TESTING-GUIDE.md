# Phase 15 Testing Quick Reference

## Test VMs
- **sorrow**: SSH port 2223, headless test VM
- **torment**: SSH port 2224, headless test VM

Both configured with:
- Auto-upgrade (hourly schedule, local mode)
- Golden generation rollback
- Build validation before switch
- Validation checks for critical services

## Quick Commands

### VM Management
```bash
# Start both VMs
just test-vm-start-all

# Check status
just test-vm-status

# SSH into VM
ssh -p 2223 root@localhost  # sorrow
ssh -p 2224 root@localhost  # torment

# Stop VMs
just test-vm-stop-all
```

### Test Execution

#### 1. Basic Auto-Upgrade Test
```bash
./scripts/test-auto-upgrade.sh sorrow
```

#### 2. Build Failure & Rollback Test
```bash
./scripts/test-rollback.sh sorrow
```

#### 3. Manual Testing Inside VM
```bash
# SSH into VM
ssh -p 2223 root@localhost

# Check current generation
nix-env --list-generations --profile /nix/var/nix/profiles/system

# Check auto-upgrade status
systemctl status nix-local-upgrade.service
journalctl -fu nix-local-upgrade.service

# Trigger manual upgrade
systemctl start nix-local-upgrade.service

# Check golden generation
golden-show
golden-pin-current

# Check git/jj state
cd ~/nix-config
jj log --limit 5
```

## Testing Checklist

### Phase 1: Single Host Tests (sorrow)
- [ ] VM boots successfully
- [ ] SSH accessible
- [ ] Auto-upgrade service enabled
- [ ] Manual upgrade works
- [ ] Build validation catches errors
- [ ] Git rollback on failure
- [ ] Services remain healthy after upgrade

### Phase 2: Boot Safety Tests (sorrow)
- [ ] Golden generation can be pinned
- [ ] Boot failure detected
- [ ] Automatic rollback to golden works
- [ ] Services restored after rollback

### Phase 3: Multi-Host Tests (both VMs)
- [ ] Concurrent upgrades don't conflict
- [ ] Both VMs can pull same changes
- [ ] No race conditions
- [ ] Network failure handles gracefully

## Expected Behavior

### Successful Upgrade
1. Pre-update hooks run (if configured)
2. Git pull succeeds
3. Build validation passes
4. Validation checks pass
5. System switches to new generation
6. Services remain active

### Failed Upgrade (build error)
1. Git pull succeeds
2. Build fails
3. Git automatically rolls back
4. System stays on current generation
5. Error logged clearly

### Failed Upgrade (validation error)
1. Git pull succeeds
2. Build succeeds
3. Validation check fails
4. Git automatically rolls back
5. System stays on current generation

### Boot Failure
1. New generation fails to boot
2. After 2 failed attempts
3. System rolls back to golden generation
4. Services restored
5. SSH accessible again

## Troubleshooting

### VM won't start
```bash
# Check for stale QEMU processes
ps aux | grep qemu

# Clean up and retry
just test-vm-stop-all
just test-vm-start sorrow
```

### SSH not accessible
```bash
# Check VM is running
just test-vm-status

# Check port forwarding
netstat -tlnp | grep 2223

# Wait for boot to complete (can take 1-2 minutes)
```

### Upgrade fails
```bash
# Check service logs
ssh -p 2223 root@localhost journalctl -u nix-local-upgrade.service -n 100

# Check git state
ssh -p 2223 root@localhost "cd ~/nix-config && jj log --limit 5"

# Verify flake inputs
ssh -p 2223 root@localhost "cd ~/nix-config && nix flake metadata"
```

## Test Results Location

Document results in: `.planning/phases/15-self-managing-infrastructure/TEST-RESULTS.md`

Include:
- Test date/time
- VM names and versions
- Test scenario name
- Expected result
- Actual result
- Pass/Fail
- Notes/observations
