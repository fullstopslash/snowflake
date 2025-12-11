# 08-01 Summary: Create roles/common.nix and Refactor Role Structure

## Completed: 2025-12-11

## What Was Done

### Task 1: Created roles/common.nix
Created universal baseline configuration that all roles inherit:
- Universal hostSpec defaults (primaryUsername, username, handle)
- Imports from nix-secrets (domain, email, userFullName, networking)
- Base secret categories (base = true for all)
- Universal system config (networking.hostName, openssh, zsh)
- Activates only when ANY role is enabled via `anyRoleEnabled` check

### Task 2: Refactored roles/default.nix
Transformed from simple import list to documented entry point:
- Imports common.nix as baseline
- Documents hardware-based roles (mutually exclusive)
- Documents task-based roles (composable) - placeholders for 08-02
- Clear comments explaining role system architecture

### Task 3: Updated Existing Roles
Fixed and updated all role files:

**desktop.nix:**
- Removed stale imports to non-existent files (audio.nix, fonts.nix, gaming.nix, thunar.nix, vlc.nix, plymouth.nix, services/greetd.nix)
- Added header comment documenting what the role provides
- Kept working imports (hyprland.nix, wayland.nix)

**laptop.nix:**
- Same cleanup as desktop.nix
- Removed stale imports (wifi.nix, services/bluetooth.nix)
- Added header comment

**server.nix, vm.nix, pi.nix, tablet.nix, darwin.nix:**
- Added consistent header comments documenting purpose
- No stale imports to remove (these were already cleaner)

## New File Structure

```
roles/
├── common.nix      # NEW: Universal baseline all roles inherit
├── default.nix     # UPDATED: Entry point, imports common + all roles
├── desktop.nix     # UPDATED: Fixed imports, added docs
├── laptop.nix      # UPDATED: Fixed imports, added docs
├── server.nix      # UPDATED: Added docs
├── vm.nix          # UPDATED: Added docs
├── pi.nix          # UPDATED: Added docs
├── tablet.nix      # UPDATED: Added docs
└── darwin.nix      # UPDATED: Added docs (placeholder)
```

## What Moved to common.nix

From hosts/common/core/default.nix pattern:
- hostSpec.primaryUsername = "rain"
- hostSpec.username = "rain"
- hostSpec.handle = "emergentmind"
- nix-secrets imports (domain, email, userFullName, networking)
- Base secretCategories
- networking.hostName setting
- Basic zsh configuration

## Build Verification

- `griefling`: Builds successfully (dry-run verified)
- `malphas`: Has pre-existing secrets configuration issue (unrelated to this PR)
  - Error: `attribute '"passwords/rain"' missing`
  - This is a sops/users configuration issue, not role system

## Key Changes

1. **Universal baseline**: All hosts with any role enabled now get consistent baseline
2. **Stale import cleanup**: Removed references to 9 non-existent files that were causing build failures
3. **Consistent documentation**: All role files now have header comments explaining their purpose
4. **Prepared for 08-02**: default.nix has placeholder comments for task-based roles

## Next Steps

- 08-02: Add task-based roles (development, mediacenter)
- Fix malphas secrets issue (separate from role system work)
