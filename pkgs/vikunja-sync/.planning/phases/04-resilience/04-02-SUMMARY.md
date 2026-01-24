# Phase 04-02 Summary: Hook Exit Code Fix and Retry Queue Consumer

## Objective
Fix hook exit code check and implement retry queue consumer with systemd timer.

## User Decision
**Retry mechanism:** systemd-timer - Native NixOS integration

## Tasks Completed

### Task 1: Fix hook exit code check
- **Status:** Previously completed (not part of this execution)
- **Implementation:** Hook scripts in vikunja-sync.nix already use heredoc pattern to properly capture exit code

### Task 2: Create retry queue consumer script
- **Status:** Previously completed
- **File:** `/home/rain/nix/pkgs/vikunja-sync/vikunja-sync-retry.py`
- **Implementation:**
  - Reads `/tmp/vikunja-sync-queue.txt` for queued UUIDs
  - Deduplicates entries
  - Calls `vikunja-direct push <uuid>` for each
  - Removes successful UUIDs, keeps failed ones in queue
  - Uses SyncLogger for consistent logging

### Task 3: Include retry script in package
- **Status:** Completed
- **File:** `/home/rain/nix/pkgs/vikunja-sync/default.nix`
- **Changes:**
  - Added `retryScript` derivation using `pkgs.writers.writePython3Bin`
  - Added `retryScript` to `paths` in `symlinkJoin`
  - Script available as `vikunja-sync-retry` in package

### Task 4: Add systemd timer for retry queue
- **Status:** Completed
- **File:** `/home/rain/nix/roles/vikunja-sync.nix`
- **Changes:**
  - Added `systemd.user.services.vikunja-sync-retry`:
    - Type: oneshot
    - Runs as user (systemd.user)
    - Requires network-online.target
    - Sets VIKUNJA_URL, VIKUNJA_USER, VIKUNJA_API_TOKEN_FILE env vars
    - Only enabled when `cfg.enableDirectSync` is true
  - Added `systemd.user.timers.vikunja-sync-retry`:
    - Triggers every 5 minutes (OnBootSec + OnUnitActiveSec)
    - WantedBy timers.target (auto-starts)
    - Only enabled when `cfg.enableDirectSync` is true

## Verification
- `nix-instantiate --parse pkgs/vikunja-sync/default.nix` - Passed
- `nix-instantiate --parse roles/vikunja-sync.nix` - Passed
- `python3 -m py_compile vikunja-sync-retry.py` - Passed

## Verification Checklist
- [x] Hook script properly captures vikunja-direct exit code (heredoc pattern)
- [x] vikunja-sync-retry.py exists and compiles
- [x] Retry script included in vikunja-sync package
- [x] systemd.user.services.vikunja-sync-retry configured
- [x] systemd.user.timers.vikunja-sync-retry configured (5 min interval)
- [x] Timer/service conditional on enableDirectSync

## Files Modified
- `/home/rain/nix/pkgs/vikunja-sync/default.nix` - Added retryScript to package
- `/home/rain/nix/roles/vikunja-sync.nix` - Added systemd user service and timer

## Architecture Notes
The retry mechanism integrates with the existing direct sync architecture:
1. Hook scripts queue failed UUIDs to `/tmp/vikunja-sync-queue.txt`
2. Timer triggers service every 5 minutes
3. Service reads queue, retries each UUID via `vikunja-direct push`
4. Successfully synced UUIDs are removed from queue
5. Failed UUIDs remain for next retry cycle

## Deviations
None. Implementation follows systemd-timer option as selected by user.
