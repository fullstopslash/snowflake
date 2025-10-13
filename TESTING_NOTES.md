# Testing the Bootstrap Script Fix

## Current Status

The bootstrap script has been updated with the following fixes for the age-key generation issue:

### Changes Made to `scripts/bootstrap-nixos.sh`:

1. **SSH Readiness Wait Loop** (lines 269-292):
   - Waits up to 60 seconds for SSH to be fully operational after reboot
   - Tests both SSH port availability AND actual connection
   - Provides clear progress feedback

2. **Known Hosts Cleanup** (line 267):
   - Clears stale SSH fingerprints before age key generation
   - Prevents conflicts between ISO and installed system fingerprints

3. **Enhanced Error Handling** in `sops_generate_host_age_key` function:
   - Added debug output showing exact commands
   - Validates ssh-keyscan results aren't empty
   - Shows both SSH and age keys in error messages
   - Confirms successful generation before proceeding

## Testing Options

### Option 1: Test with the VM (Full Test)

**Requirements:**
- The test VM needs to be booted into the NixOS ISO
- SSH access must be configured manually first (the ISO might not have your SSH key)

**Steps:**
1. In the VM window (which should be visible), log in as `nixos` (or `fullstopslash`)
2. Set a password: `sudo passwd root` (use something simple like "test")
3. Enable password auth temporarily:
   ```bash
   sudo sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
   sudo sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
   sudo systemctl restart sshd
   ```
4. Test SSH from your host:
   ```bash
   ssh -p 22220 root@localhost  # password: test
   ```
5. Run the bootstrap script:
   ```bash
   ./scripts/bootstrap-nixos.sh -n guppy -d localhost -k ~/.ssh/id_ed25519 --port 22220 --debug
   ```

### Option 2: Test with a Real Target (Recommended)

If you have an actual target machine to install:
```bash
./scripts/bootstrap-nixos.sh -n [hostname] -d [ip_address] -k ~/.ssh/id_ed25519 --debug
```

The key improvement to test is the **age key generation step**:
- After nixos-anywhere completes and the system reboots
- When prompted "Generate host (ssh-based) age key?"
- The script should now wait properly for SSH and not fail immediately

## What to Look For

### Success Indicators:
- ✅ "Waiting for SSH service to be ready..."
- ✅ "Attempt N/30 - waiting 2 seconds..." messages
- ✅ "SSH service is ready and accepting connections!"
- ✅ "Running ssh-keyscan on [destination]:[port]..."
- ✅ "Converting SSH key to age key..."
- ✅ "Successfully generated age key: age1..."

### Previously Would Fail:
- ❌ Immediate disconnection after reboot
- ❌ "Failed to get ssh key" with no wait time
- ❌ Empty ssh-keyscan results

## Files Modified

- `/home/rain/nix-config/scripts/bootstrap-nixos.sh` - Main fixes
- `/home/rain/nix-config/test-bootstrap.sh` - Helper script for VM testing (optional)

## Cleanup

If testing with the VM, you can stop it with:
```bash
pkill -f "qemu.*nixos-test"
```

And recreate the disk if needed:
```bash
rm nixos-test.qcow2
qemu-img create -f qcow2 nixos-test.qcow2 32G
```

