---
phase: 07-vikunja-hardening
plan: 04
type: summary
---

# Summary: Python Script Hardening

## Tasks Completed

### Task 1: Add file locking to prevent duplicate task creation
- Added `fcntl.flock()` based locking with non-blocking acquisition
- Lock file at `~/.local/state/vikunja-sync/direct.lock`
- Applied to both `cmd_hook()` and `cmd_webhook()` functions
- When lock unavailable, hook queues UUID for retry instead of blocking
- Webhook returns error when lock unavailable (systemd will retry)

New functions added:
- `get_state_dir()` - returns `~/.local/state/vikunja-sync`
- `get_lock_file()` - returns lock file path
- `acquire_lock()` - non-blocking lock acquisition
- `release_lock()` - lock release
- `queue_for_retry()` - queues UUID to retry file

### Task 2: Add vikunja_id annotation on title-match updates
- Added `annotate_vikunja_id()` function to annotate TW tasks
- Function uses `task annotate` with `VIKUNJA_SYNC_RUNNING=1` to prevent recursion
- Applied in `push_to_vikunja()` after:
  1. Creating a new task in Vikunja (annotate with new ID)
  2. Updating a task found by title-match (annotate to enable future direct lookup)

Benefits:
- Future syncs use direct ID lookup (faster, more reliable)
- No orphaned tasks without vikunja_id
- Bidirectional sync works correctly

### Task 3: Use user-specific log/state paths
- Added `get_state_dir()` helper that creates `~/.local/state/vikunja-sync`
- Lock file and queue file now use this directory
- Consistent with shell script paths from 07-01

Note: Actual log output still goes to stderr (redirected by shell wrapper).
The state directory is used for lock files and retry queues.

## Verification

- [x] Python scripts pass syntax check (`python -m py_compile`)
- [x] Python scripts have file locking via `fcntl.flock()`
- [x] Title-matched tasks get vikunja_id annotated
- [x] State directory is `~/.local/state/vikunja-sync`
- [x] Lock file path is user-specific

## Files Modified

- `pkgs/vikunja-sync/vikunja-direct.py`
  - Added `fcntl` import
  - Added `get_state_dir()`, `get_lock_file()`, `acquire_lock()`, `release_lock()` functions
  - Added `annotate_vikunja_id()` function
  - Added `queue_for_retry()` function
  - Updated `push_to_vikunja()` to annotate vikunja_id on create and title-match
  - Updated `cmd_hook()` with file locking and retry queue fallback
  - Updated `cmd_webhook()` with file locking
