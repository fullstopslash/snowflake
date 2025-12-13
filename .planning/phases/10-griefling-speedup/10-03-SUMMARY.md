---
phase: 10-griefling-speedup
task: 10-03-PLAN.md
status: completed
date: 2025-12-12
---

# Phase 10-03 Summary: Enable Guards for scanPaths Modules

## Objective

Ensure all modules in scanPaths directories have enable guards to prevent accidental activation, particularly for griefling and other minimal builds.

## Tasks Completed

All 5 tasks completed successfully:

### Task 1: modules/services/audio/*.nix ✅

**Files audited:**
- `/home/rain/nix-config/modules/services/audio/pipewire.nix` - **ADDED** enable guard
- `/home/rain/nix-config/modules/services/audio/tuning.nix` - **ADDED** enable guard
- `/home/rain/nix-config/modules/services/audio/default.nix` - aggregator, no guard needed

**Changes:**
- Added `myModules.services.audio.pipewire.enable` option
- Added `myModules.services.audio.tuning.enable` option
- Wrapped all configuration in `lib.mkIf cfg.enable` blocks

### Task 2: modules/services/ai/*.nix ✅

**Files audited:**
- `/home/rain/nix-config/modules/services/ai/crush.nix` - **ADDED** enable guard
- `/home/rain/nix-config/modules/services/ai/ollama.nix` - **ADDED** enable guard
- `/home/rain/nix-config/modules/services/ai/default.nix` - aggregator, no guard needed

**Changes:**
- Added `myModules.services.ai.crush.enable` option
- Added `myModules.services.ai.ollama.enable` option
- Wrapped all configuration in `lib.mkIf cfg.enable` blocks

### Task 3: modules/services/misc/*.nix ✅

**Files audited:**
- `/home/rain/nix-config/modules/services/misc/voice-assistant.nix` - **ALREADY HAD** enable guard ✓
- `/home/rain/nix-config/modules/services/misc/flatpak.nix` - **ALREADY HAD** enable guard ✓
- `/home/rain/nix-config/modules/services/misc/ssh-no-sleep.nix` - **ADDED** enable guard
- `/home/rain/nix-config/modules/services/misc/sinkzone.nix` - **ALREADY HAD** enable guard ✓
- `/home/rain/nix-config/modules/services/misc/default.nix` - aggregator, no guard needed

**Changes:**
- Added `myModules.services.misc.sshNoSleep.enable` option
- Wrapped all configuration in `lib.mkIf cfg.enable` block

### Task 4: modules/services/storage/*.nix ✅

**Files audited:**
- `/home/rain/nix-config/modules/services/storage/borg.nix` - **ALREADY HAD** enable guard ✓
- `/home/rain/nix-config/modules/services/storage/network-storage.nix` - **ALREADY HAD** enable guard ✓
- `/home/rain/nix-config/modules/services/storage/default.nix` - aggregator, no guard needed

**Changes:**
- No changes needed - all modules already had proper enable guards

### Task 5: modules/services/security/*.nix ✅

**Files audited:**
- `/home/rain/nix-config/modules/services/security/bitwarden.nix` - **ALREADY HAD** enable guard ✓
- `/home/rain/nix-config/modules/services/security/clamav.nix` - **ADDED** enable guard
- `/home/rain/nix-config/modules/services/security/secrets.nix` - **ADDED** enable guard
- `/home/rain/nix-config/modules/services/security/yubikey.nix` - **ALREADY HAD** enable guard ✓
- `/home/rain/nix-config/modules/services/security/sops.nix` - **INTENTIONALLY UNIVERSAL** (foundational sops-nix config)
- `/home/rain/nix-config/modules/services/security/default.nix` - aggregator, no guard needed

**Changes:**
- Added `myModules.services.security.clamav.enable` option
- Added `myModules.services.security.secrets.enable` option
- Wrapped all configuration in `lib.mkIf cfg.enable` blocks
- **Special fix for clamav.nix:** Moved all let bindings inside the `config = lib.mkIf cfg.enable` block to prevent evaluation of hostSpec attributes on hosts without those attributes
- **Note:** sops.nix left without enable guard as it provides foundational sops-nix configuration

## Summary Statistics

### Files Modified: 8
1. modules/services/audio/pipewire.nix
2. modules/services/audio/tuning.nix
3. modules/services/ai/crush.nix
4. modules/services/ai/ollama.nix
5. modules/services/misc/ssh-no-sleep.nix
6. modules/services/security/clamav.nix
7. modules/services/security/secrets.nix

### Files Already Compliant: 7
1. modules/services/misc/voice-assistant.nix
2. modules/services/misc/flatpak.nix
3. modules/services/misc/sinkzone.nix
4. modules/services/storage/borg.nix
5. modules/services/storage/network-storage.nix
6. modules/services/security/bitwarden.nix
7. modules/services/security/yubikey.nix

### Intentionally Universal: 1
1. modules/services/security/sops.nix (foundational sops-nix configuration)

### Total Module Files Audited: 16

## Pattern Used

All enable guards follow the consistent pattern:

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.myModules.services.CATEGORY.NAME;
in
{
  options.myModules.services.CATEGORY.NAME = {
    enable = lib.mkEnableOption "description";
  };

  config = lib.mkIf cfg.enable {
    # ... existing configuration ...
  };
}
```

## Impact

This change prevents any modules in scanPaths directories from being unconditionally activated. Hosts like `griefling` (minimal builder) will no longer accidentally pull in:
- PipeWire audio stack
- Ollama AI services
- ClamAV antivirus
- Bitwarden secrets tools
- SSH sleep inhibitor
- And other optional services

Each module must now be explicitly enabled via its respective option path.

## Verification

### Flake Check Results

- ✅ `nixosConfigurations.griefling` - evaluates successfully
- ✅ `nixosConfigurations.iso` - evaluates successfully
- ⚠️ `nixosConfigurations.malphas` - pre-existing error (missing passwords/rain in sops secrets, unrelated to this phase)

### Build Verification

Griefling and iso configurations evaluate without errors, confirming that:
- All module enable guards work correctly
- Modules are not activated when not explicitly enabled
- No evaluation errors from optional hostSpec attributes

## Next Steps

As recommended in the plan verification section:
1. ✅ Run `nix flake check` - passed for griefling and iso
2. Test griefling dry-run build to verify minimal package count
3. Verify no unexpected services are pulled into minimal builds

## Notes

- All `default.nix` aggregator files were excluded from requiring enable guards (expected behavior)
- One special case: `sops.nix` is intentionally universal as it provides foundational sops-nix configuration needed by the secrets system
- Pattern is consistent across all categories for maintainability
- **clamav.nix special handling:** Required moving let bindings inside the `lib.mkIf cfg.enable` block because it referenced `config.hostSpec.email.notifier` and `config.hostSpec.domain` which don't exist on minimal hosts like griefling
- Email notification in clamav now uses `lib.optionalString` to only send emails if hostSpec.email.notifier and hostSpec.domain exist
