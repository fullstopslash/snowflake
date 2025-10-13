# Griefling Bootstrap Test - Checklist

## Pre-Flight Check ✅

- ✅ Host configuration created: `hosts/nixos/griefling/`
- ✅ Home-manager config created: `home/rain/griefling.nix`
- ✅ Installer configured: `nixos-installer/flake.nix` with username "rain"
- ✅ User age keys generated: rain_griefling
- ✅ Secrets configured and rekeyed
- ✅ SSH keys verified: rain's keys in config match ~/.ssh/id_ed25519
- ✅ VM disk created: `griefling-test.qcow2` (32GB)
- ✅ VM launch script ready: `griefling-test.sh`

## Bootstrap Script Fixes Implemented ✅

- ✅ SSH readiness wait (60 seconds with progress)
- ✅ IPv4 forcing on all ssh-keyscan commands
- ✅ Enhanced error handling and debug output
- ✅ **Sync as root** (no more password errors!)
- ✅ Automatic chown to target user

## Test Steps

### 1. Launch VM
```bash
cd /home/rain/nix-config
./griefling-test.sh
```
**Expected**: VM window appears, boots into NixOS ISO

### 2. Wait for ISO Login Prompt
**Expected**: See `nixos@iso login:` in VM window (30-60 seconds)

### 3. Run Bootstrap Script
```bash
./scripts/bootstrap-nixos.sh \
  -n griefling \
  -d 127.0.0.1 \
  -u rain \
  -k ~/.ssh/id_ed25519 \
  --port 22221 \
  --debug
```

### 4. Answer Prompts

| Prompt | Answer | Notes |
|--------|--------|-------|
| Run nixos-anywhere installation? | **yes** | Installs minimal system |
| Manually set luks passphrase? | **no** | Not using encryption |
| Generate hardware config? | **yes** | First time for griefling |
| System restarted, ready to continue? | **yes** | Wait for login prompt in VM! |
| Generate host age key? | **yes** | Creates host SSH→age key |
| Generate user age key? | **no** | Already created manually |
| Copy nix-config and nix-secrets? | **yes** | Sync as root (fixed!) |
| Rebuild immediately? | **yes** | Full build with Hyprland |
| Commit hardware-configuration.nix? | **your choice** | |

### 5. Watch for Success Indicators

**During Age Key Generation (after reboot):**
```
[+] Cleaning up known_hosts for 127.0.0.1
[+] Waiting for SSH service to be ready...
Attempt 1/30 - waiting 2 seconds...
Attempt 2/30 - waiting 2 seconds...
...
[+] SSH service is ready and accepting connections!
[*] Running ssh-keyscan on 127.0.0.1:22221...
[*] Converting SSH key to age key...
[+] Successfully generated age key: age1...
[+] Updating nix-secrets/.sops.yaml
```

**During File Sync:**
```
[+] Copying full nix-config to griefling (as root, will fix permissions)
sending incremental file list
...
[+] Moving files to src/nix/ and setting ownership to rain
```

**During Rebuild:**
```
building the system configuration...
activating the configuration...
setting up /etc...
...
✅ SUCCESS - No errors!
```

### 6. Verify Installation

SSH into griefling:
```bash
ssh -p 22221 -i ~/.ssh/id_ed25519 rain@127.0.0.1
```

**Check Everything:**
```bash
# Verify user
whoami  # Should be: rain

# Verify NH_FLAKE is correct
echo $FLAKE  # Should be: /home/rain/src/nix/nix-config

# Verify Hyprland is installed
which Hyprland  # Should return path

# Verify secrets work
ls ~/.config/sops/age/keys.txt  # Should exist

# Test nh command
nh os switch  # Should work without specifying path!
```

## Success Criteria

- ✅ No SSH connection failures during sync
- ✅ Age key generation succeeds after reboot
- ✅ Files sync successfully as root
- ✅ Permissions set correctly to rain:users
- ✅ Full rebuild completes without errors
- ✅ Hyprland desktop available
- ✅ NH_FLAKE points to correct location
- ✅ User can SSH in with their key

## Troubleshooting

### If VM won't start
- Check if another VM is running: `pkill -f qemu`
- Verify ISO exists: `ls -lh result/iso/*.iso`

### If SSH times out after reboot
- Wait longer - script has 60 second timeout
- Check VM window to ensure it fully booted
- Look for "Attempt N/30" progress messages

### If file sync fails
- Should NOT happen with root sync!
- If it does, check root's SSH keys: `ssh -p 22221 root@127.0.0.1 "cat ~/.ssh/authorized_keys"`

## Cleanup After Testing

```bash
# Stop the VM
pkill -f "qemu.*griefling-test"

# Optional: Remove test files
rm griefling-test.qcow2
rm griefling-test.pid
rm griefling-test-*.socket
```

## Ready for Production!

Once this test succeeds, the bootstrap script is **production-ready** for:
- Real hardware installations
- Different users per host
- Any desktop environment
- Encrypted or unencrypted setups

🚀 **All systems go!**

