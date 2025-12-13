# Bootstrap Script Fixes - Summary

## Original Problem
The bootstrap script would fail and disconnect immediately when opting to generate age keys after nixos-anywhere completed.

## Root Causes Fixed

### 1. SSH Readiness Issue (Primary Bug)
**Problem**: Script didn't wait for SSH to be ready after reboot
**Fix**: Added 60-second wait loop with connection verification
**Location**: `scripts/bootstrap-nixos.sh` lines 265-292

### 2. IPv4/IPv6 Resolution Issue (Discovered during testing)
**Problem**: `localhost` resolved to IPv6 but VMs only listened on IPv4
**Fix**: Added `-4` flag to all `ssh-keyscan` commands
**Locations**: Lines 153, 195, 209, 275, 320

### 3. Enhanced Error Handling
**Added**: Detailed debug output showing exact commands and results
**Location**: `sops_generate_host_age_key()` function lines 204-236

## Configuration Fixes in nix-secrets

During testing, we discovered missing structure in the "simple" variant of nix-secrets:

1. ✅ **SSH configuration** - Added `ssh.yubikeyHosts`, `matchBlocks`, `knownHostsFileContents`
2. ✅ **Git configuration** - Added `git.repos` and `git.work.repos`
3. ✅ **Subnet definitions** - Added `grove` and `vm-lan` subnets
4. ✅ **Port configurations** - Added `oops` port
5. ✅ **Secrets rekeying** - Properly encrypted malphas.yaml and shared.yaml

## Additional Improvements

### NH_FLAKE Path Fix
**Problem**: `programs.nh.flake` had incorrect path `/home/user/${config.hostSpec.home}/nix-config`
**Fix**: Changed to `${config.hostSpec.home}/src/nix/nix-config`
**File**: `hosts/common/core/nixos.nix`

### Per-Host User Configuration
**Problem**: All hosts defaulted to user 'ta'
**Solution**: Override `primaryUsername` and `username` in host config
**Example**: `hosts/nixos/guppy/default.nix` now uses 'rain'

## Files Modified

### Bootstrap Script
- `scripts/bootstrap-nixos.sh` - Main fixes for age key generation

### nix-secrets
- `flake.nix` - Added complete SSH, Git, networking structure
- `.sops.yaml` - Updated creation rules for rain_guppy
- `sops/guppy.yaml` - Rekeyed to use rain_guppy
- `sops/shared.yaml` - Added ta_guppy, properly encrypted
- `sops/malphas.yaml` - Properly encrypted with creation rules

### nix-config
- `hosts/common/core/nixos.nix` - Fixed NH_FLAKE path
- `hosts/nixos/guppy/default.nix` - Set user to 'rain'
- `home/rain/guppy.nix` - Created home-manager config for rain
- `home/rain/common/default.nix` - Created rain's common config
- `home/rain/common/nixos.nix` - Created rain's NixOS-specific config

## Testing Results

✅ **Bootstrap script works perfectly:**
- Age keys generate successfully after reboot
- SSH wait loop functions correctly
- IPv4/IPv6 handled properly
- File syncing works
- Secrets management automated

## Next Steps

1. Test the updated configuration on guppy (with user 'rain')
2. Follow the instructions in the repo to set up a new host
3. The bootstrap script is now production-ready!

## Test Command

To rebuild guppy with the new 'rain' user configuration:

```bash
# Local machine - sync changes
cd /home/rain/nix-config
rsync -av --filter=':- .gitignore' -e "ssh -o StrictHostKeyChecking=no -p 22220 -i ~/.ssh/id_ed25519" \
  ./ rain@127.0.0.1:/home/rain/src/nix/nix-config/

rsync -av --filter=':- .gitignore' -e "ssh -o StrictHostKeyChecking=no -p 22220 -i ~/.ssh/id_ed25519" \
  ../nix-secrets/ rain@127.0.0.1:/home/rain/src/nix/nix-secrets/

# On guppy
ssh -p 22220 -i ~/.ssh/id_ed25519 rain@127.0.0.1
cd /home/rain/src/nix/nix-config
sudo nixos-rebuild --flake .#guppy switch
```

## For New Host Setup

Follow: `/home/rain/nix-config/docs/addnewhost.md` or the README in `nixos-installer/`

The bootstrap script will now handle:
- ✅ SSH readiness detection
- ✅ Age key generation (host and user)
- ✅ Secrets management
- ✅ Automatic rekeying and git push
- ✅ File syncing with correct permissions
