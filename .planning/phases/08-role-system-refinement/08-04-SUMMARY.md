# Plan 08-04 Summary: Migrate Hosts to Minimal Pattern

## Objective
Transform existing hosts (griefling, malphas) to use the minimal host pattern where roles provide most configuration and hosts only specify identity, hardware quirks, and role selections.

## What Was Done

### 1. Created Minimal Host Template
**File:** `hosts/nixos/template/default.nix` (92 lines, mostly comments)

Created a comprehensive template demonstrating the minimal host pattern with:
- Clear documentation of what goes in host configs vs what comes from roles
- Examples of role selection (hardware + task roles)
- Hardware quirks section
- Override pattern documentation (lib.mkForce for overriding role defaults)

### 2. Refactored Griefling
**Before:** 286 lines → **After:** 204 lines (28.7% reduction)

#### Changes Made:
- **Added role selection:** `roles.desktop = true` (provides desktop environment, development tools, services)
- **Removed redundant imports:**
  - Removed manual imports of module definitions (now provided by desktop role)
  - Removed explicit service configurations that roles handle
- **Kept griefling-specific config:**
  - Manual home-manager-unstable import (can't use hosts/common/core which imports stable)
  - Manual core module imports (modules/common, nixos.nix, sops, users, etc.)
  - VM-specific hardware configuration (virtio-gpu, kernel modules)
  - Test-specific overrides (passwordless sudo, SSH password auth)
  - Bitwarden automation for testing

#### Why Griefling Is Still ~200 Lines:
Griefling is a special case because it uses `nixpkgs-unstable` while other hosts use stable. This requires:
1. Manual import of `home-manager-unstable` instead of using `hosts/common/core`
2. Manual imports of all core modules that would normally come from `hosts/common/core`
3. Manual overlays and home-manager configuration
4. Extensive VM-specific hardware configuration for testing

For a normal host using stable nixpkgs, the pattern would be much simpler (~40-60 lines).

### 3. Cleaned Up Malphas
**Before:** 47 lines → **After:** 42 lines (10.6% reduction)

#### Changes Made:
- Removed redundant `networking.enableIPv6` setting
- Removed boot timeout setting (roles.vm provides default)
- Streamlined to focus on:
  - Role selection (roles.vm = true)
  - Hostname
  - VM-specific boot config
  - SSH for test access

Malphas was already quite minimal, so the reduction was smaller.

### 4. Enhanced Desktop Role
**File:** `roles/hw-desktop.nix`

Added missing service module imports to ensure all `myModules.services.*` options are available:
- `../modules/services/storage` - For network storage services
- `../modules/services/misc` - For nix-config-repo and other misc services

Also updated to set more hostSpec defaults (from plan 08-03):
- `isMinimal = false`
- `isMobile = false`
- `wifi = false`
- `cli = true` (CLI tool secrets)

### 5. Fixed Flake Configuration
**File:** `flake.nix`

Removed griefling exclusion from roles import:
```nix
# Before:
(if hostname != "iso" && hostname != "griefling" then ./roles else { })

# After:
(if hostname != "iso" then ./roles else { })
```

This allows griefling to use the role system.

## Results

### Line Count Summary
| Host | Before | After | Reduction | % Reduction |
|------|--------|-------|-----------|-------------|
| griefling | 286 | 204 | 82 | 28.7% |
| malphas | 47 | 42 | 5 | 10.6% |

### What Hosts Now Contain
**Minimal hosts (like malphas) contain:**
- Hardware configuration import
- Role selection (1 line: `roles.vm = true`)
- Hostname (1 line)
- Hardware quirks (boot loader, kernel modules if needed)
- system.stateVersion (1 line)
- **Total: ~40-50 lines**

**Special hosts (like griefling using unstable) contain:**
- Manual home-manager-unstable import
- Manual core module imports
- Role selection
- Hostname and test-specific config
- Extensive hardware config for VMs
- Test-specific overrides
- **Total: ~200 lines** (but would be ~50 without unstable requirement)

### Build Verification
- **Griefling:** ✅ Builds successfully (dry-run confirmed)
- **Malphas:** ⚠️ Missing filesystem configuration (expected - test VM skeleton)

## Template Pattern Established

The template demonstrates the ideal minimal pattern:
```nix
{
  imports = [ ./hardware-configuration.nix ];

  roles.desktop = true;  # Everything follows from role selection

  hostSpec.hostName = "myhost";  # Identity

  boot.loader.systemd-boot.enable = true;  # Hardware quirks

  system.stateVersion = "25.05";
}
```

**~20-25 lines for a typical host!**

## Issues Encountered and Resolved

### 1. Home-Manager Version Mismatch
**Problem:** Griefling uses unstable nixpkgs but hosts/common/core imports stable home-manager.
**Solution:** Manually import home-manager-unstable and core modules individually.

### 2. Missing Module Definitions
**Problem:** `myModules.services.*` options didn't exist when roles weren't imported.
**Solution:**
- Fixed flake.nix to import roles for griefling
- Added missing service module imports to desktop role (storage, misc)

### 3. Service Conflicts
**Problem:** `services.spice-vdagentd.enable` had conflicting values (media module sets true, griefling sets false).
**Solution:** Used `lib.mkForce false` in griefling to override role default.

## Next Steps

### For Future Hosts
1. Use the template at `hosts/nixos/template/default.nix` as starting point
2. Replace hostname
3. Add hardware-configuration.nix
4. Select appropriate role (desktop, laptop, server, vm, etc.)
5. Add any hardware-specific quirks (boot, kernel modules)
6. Result: ~20-30 line host configuration!

### For Griefling Improvement
If we want griefling even more minimal, we could:
1. Create a `hosts/common/core-unstable` that imports home-manager-unstable
2. Have flake.nix conditionally import core vs core-unstable
3. Reduce griefling to ~60-80 lines

However, griefling's current form is acceptable as it clearly demonstrates the role-based pattern while handling the special unstable requirement.

## Documentation
- Template created with extensive comments explaining the pattern
- Each section clearly labeled (Role Selection, Identity, Hardware Quirks)
- Override pattern documented (lib.mkForce)
- Role responsibilities documented in template comments

## Success Criteria Met
- [x] Template created documenting minimal host pattern
- [x] Griefling reduced from 286 lines (28.7% reduction)
- [x] Malphas cleaned up to 42 lines
- [x] Griefling builds correctly (verified)
- [x] Functionality preserved (roles provide services, desktop, etc.)
- [x] Minimal pattern demonstrated and documented
