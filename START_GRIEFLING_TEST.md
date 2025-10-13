# Quick Start: Test Griefling Bootstrap

## Ready to Test!

All configurations are in place. Here's how to test the bootstrap process:

### Step 1: Start the Griefling VM

```bash
cd /home/rain/nix-config
./griefling-test.sh
```

A window will appear showing the VM booting into the ISO.

### Step 2: Wait for ISO Boot

Wait until you see a login prompt in the VM window (usually 30-60 seconds).

### Step 3: Run Bootstrap Script

```bash
./scripts/bootstrap-nixos.sh \
  -n griefling \
  -d 127.0.0.1 \
  -u rain \
  -k ~/.ssh/id_ed25519 \
  --port 22221 \
  --debug
```

### Step 4: Answer Prompts

1. **Run nixos-anywhere installation?** → yes
2. **Manually set luks encryption passphrase?** → no (not using LUKS)
3. **Generate a new hardware config for this host?** → yes (first time)
4. **Has your system restarted and are you ready to continue?** → yes (after VM reboots)
5. **Generate host (ssh-based) age key?** → yes
6. **Generate user age key?** → no (we already created it manually)
7. **Copy nix-config and nix-secrets?** → yes
8. **Rebuild immediately?** → yes
9. **Commit hardware-configuration.nix?** → your choice

### What You'll See (The Fixes Working!)

After the VM reboots (step 4):
- ✅ "Cleaning up known_hosts for 127.0.0.1"
- ✅ "Waiting for SSH service to be ready..."
- ✅ "Attempt 1/30 - waiting 2 seconds..." (with progress)
- ✅ "SSH service is ready and accepting connections!"
- ✅ "Running ssh-keyscan on 127.0.0.1:22221..."
- ✅ "Successfully generated age key: age1..."
- ✅ Files sync successfully
- ✅ System rebuilds with Hyprland!

### Step 5: Verify Success

After bootstrap completes, SSH into griefling:

```bash
ssh -p 22221 -i ~/.ssh/id_ed25519 rain@127.0.0.1
```

Check that Hyprland is installed:

```bash
which Hyprland
echo $FLAKE  # Should show /home/rain/src/nix/nix-config
```

## Configuration Summary

**Host**: griefling  
**User**: rain  
**Desktop**: Hyprland + Wayland  
**RAM**: 8GB  
**Disk**: 32GB virtual (no swap, no LUKS)  
**SSH Port**: 22221

## Troubleshooting

If the VM doesn't start:
- Check if guppy test VM is still running: `pkill -f "qemu.*nixos-test"`
- Verify ISO exists: `ls -lh result/iso/*.iso`

If SSH times out:
- The script will now wait up to 60 seconds
- Watch the VM window to see if it's fully booted
- The fixes will show clear progress messages

## Cleanup

When done testing:

```bash
# Stop the VM
pkill -f "qemu.*griefling-test"

# Optional: Clean up test files
rm griefling-test.qcow2 griefling-test.pid griefling-test-*.socket
```

## Next Steps After Successful Bootstrap

1. Verify Hyprland works (should auto-start on login)
2. Test `nh os switch` (NH_FLAKE should be set correctly)
3. Verify secrets work (sops keys should be in place)
4. Ready to use this process for real hardware!

🎉 You now have a production-ready bootstrap process!

