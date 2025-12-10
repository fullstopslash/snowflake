# Summary 16-01: Fix ISO Install Commands and VM Testing

## What Was Broken

1. **Wrong disko path in ISO bash history:**
   - Was: `./disks/btrfs-luks-impermanence-disko.nix` (doesn't exist)
   - Correct: `hosts/common/disks/btrfs-luks-impermanence-disk.nix`

2. **Wrong disko path in justfile:**
   - Same issue in the `disko` recipe

3. **Missing LUKS password setup:**
   - Disko with LUKS requires `/tmp/disko-password` file
   - Users had no guidance on creating it

4. **nixos-anywhere mode didn't boot from ISO:**
   - VM started without boot media
   - Should boot ISO first, then nixos-anywhere takes over via SSH

## What Was Fixed

### hosts/nixos/iso/default.nix
- Fixed disko path to `hosts/common/disks/btrfs-luks-impermanence-disk.nix`
- Added inline password setup: `echo "changeme" | sudo tee /tmp/disko-password`
- Changed mode to `--mode format,mount` (correct for full setup)

### scripts/test-fresh-install.sh
- ISO is now built for BOTH manual and nixos-anywhere modes
- nixos-anywhere mode boots VM from ISO first
- Added proper SSH timeout handling (90 iterations, 3 min max)
- Verify host config exists before starting VM

### justfile
- Added `test-install` - one-command automated install via nixos-anywhere
- Added `test-install-manual` - interactive ISO boot
- Fixed `disko` recipe to use correct path and `--mode format,mount`

## New Workflow

### One-Command Automated Install (nixos-anywhere)
```bash
just test-install griefling
```
This wipes VM, boots ISO, waits for SSH, runs nixos-anywhere, reboots into installed system.

### Interactive Manual Install (ISO)
```bash
just test-install-manual griefling
```
Then press Up Arrow twice to get:
1. `echo "changeme" | sudo tee /tmp/disko-password && cd /etc/nix-config && sudo nix ... disko ...`
2. `cd /etc/nix-config && sudo nixos-install --flake .#griefling --no-root-passwd`

## Files Modified
- `hosts/nixos/iso/default.nix` - Fixed bash history
- `scripts/test-fresh-install.sh` - Fixed nixos-anywhere mode
- `justfile` - Added recipes, fixed disko path

## Verification
- [x] ISO builds successfully
- [x] VM boots from ISO
- [x] SSH works
- [x] Bash history has correct disko command with password setup
- [x] Disko config exists at `/etc/nix-config/hosts/common/disks/`

## Deviations
- Also fixed the `disko` recipe in justfile (discovered during implementation)
