---
phase: 08-vikunja-complete-sync
plan: 03
type: summary
---

# Summary: Hook Stability & Diagnostics

**Added comprehensive diagnostics, queue processing, and self-test capabilities.**

## Accomplishments

- Added `vikunja-direct diagnose` command for system health checks
- Added `vikunja-direct process-queue` command for manual retry processing
- Enhanced activation script with hook validation warnings
- Added self-test systemd user service that runs at login

## Files Modified

- `pkgs/vikunja-sync/vikunja-direct.py`
  - Added `cmd_diagnose()` - Comprehensive health check
  - Added `cmd_process_queue()` - Manual retry queue processing
  - Updated `main()` with new command dispatch and help text

- `roles/vikunja-sync.nix`
  - Enhanced activation script with hook validation
  - Added `vikunja-sync-selftest` user service

## New CLI Commands

### `vikunja-direct diagnose`
Checks:
- Environment variables (VIKUNJA_URL, VIKUNJA_API_TOKEN_FILE, VIKUNJA_USER)
- Token file readability
- TW hook symlinks (existence, target validity, executable permission)
- Required binaries (task, jaq, curl)
- State directory and queue file status
- Vikunja API connectivity

### `vikunja-direct process-queue`
- Reads queued UUIDs from `~/.local/state/vikunja-sync/queue.txt`
- Attempts to push each task to Vikunja
- Updates queue file with only failed items
- Reports processed/failed counts

## NixOS Integration

### Activation Script Validation
During `nh os switch`, the activation script now:
1. Installs hooks as before
2. Validates each hook target exists and is executable
3. Checks `vikunja-direct` is in PATH
4. Reports warnings (doesn't fail activation)

### Self-Test Service
```nix
systemd.user.services.vikunja-sync-selftest
```
- Runs at user login (`default.target`)
- Executes `vikunja-direct diagnose`
- Logs output for debugging
- Non-blocking (doesn't fail on errors)

## Verification

- [x] Python syntax valid
- [x] Nix syntax valid
- [x] `diagnose` command checks all system components
- [x] `process-queue` retries queued items
- [x] Activation script includes validation
- [x] Self-test service configured

## Next Step

Phase complete. Ready for rebuild and testing.
