# Phase 14-01 Summary: Role Elegance Fixes

## Status: Complete

## Changes Made

### Task 1: form-pi.nix
- **File**: `roles/form-pi.nix`
- **Change**: Removed redundant `services.openssh.enable = lib.mkDefault true;` (was line 30)
- **Reason**: Line 20 already has `modules.services.networking = [ "openssh" ]` which enables the module via selection system

### Task 2: form-server.nix
- **File**: `roles/form-server.nix`
- **Change**: Removed redundant `services.openssh.enable = lib.mkDefault true;` (was line 32)
- **Reason**: Lines 22-25 already have `modules.services.networking = [ "ssh" "openssh" ]` which enables the module via selection system

### Task 3: task-test.nix
- **File**: `roles/task-test.nix`
- **Changes**:
  1. Added MODULE SELECTIONS section with `modules.services.cli = [ "atuin" ]` and `modules.services.networking = [ "syncthing" ]`
  2. Removed `myModules.services.cli.atuin.enable = true;` (was line 44)
  3. Removed `myModules.services.networking.syncthing.enable = true;` (was line 47)
- **Kept**: `myModules.services.nixConfigRepo.enable = true;` because nixConfigRepo is in `modules/common/` not `modules/services/`, so it's outside the filesystem-driven selection system

## Verification Results

### Per-file verification:
```
=== form-pi.nix ===
20:        networking = [ "openssh" ];
(Only module selection, no direct enable)

=== form-server.nix ===
24:          "openssh"
(Only module selection, no direct enable)

=== task-test.nix myModules ===
41:    myModules.services.nixConfigRepo.enable = true;
(Only nixConfigRepo, which is in modules/common/)
```

### Global verification:
- No redundant `services.*.enable` in roles (except legitimate hardware/boot)
- No redundant `myModules.*.enable` in roles (except modules/common/)
- Build test passed: griefling configuration builds successfully

## Deviations

None. Plan executed as specified.

## Files Modified

| File | Lines Changed |
|------|---------------|
| `roles/form-pi.nix` | -1 (removed line 30) |
| `roles/form-server.nix` | -1 (removed line 32) |
| `roles/task-test.nix` | +11, -6 (added selection section, removed direct enables) |

## Outcome

All roles now consistently use the unified module selection system:
- `modules.<top>.<category> = [ "name" ]` for service enables
- Direct NixOS options only for hardware/boot with no module wrapper
- Direct `myModules.*.enable` only for modules outside selection system (e.g., `modules/common/`)
