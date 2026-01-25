---
phase: 09-vikunja-sync-fixes
plan: 03
type: summary
---

# Summary: Queue Atomicity & Deduplication

**Added file locking to queue operations and consolidated queue processors.**

## Accomplishments

- Added `get_queue_lock_file()` helper function
- Added file locking to `queue_for_retry()` for atomic appends
- Rewrote `cmd_process_queue()` with lock held for entire operation
- Consolidated retry service to use Python processor instead of shell script

## Files Modified

- `pkgs/vikunja-sync/vikunja-direct.py`
  - Added `get_queue_lock_file()` function
  - `queue_for_retry()` - Now uses flock for atomic appends
  - `cmd_process_queue()` - Holds lock for entire processing cycle

- `roles/vikunja-sync.nix`
  - `vikunja-sync-retry` service now uses `vikunja-direct process-queue`

## Technical Details

### Queue Locking

Both queue writing and processing now use the same lock file (`queue.lock`):

```python
def queue_for_retry(uuid: str) -> None:
    lock_fd = os.open(str(lock_file), os.O_WRONLY | os.O_CREAT, 0o644)
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX)
        with open(queue_file, "a") as f:
            f.write(f"{uuid}\n")
    finally:
        fcntl.flock(lock_fd, fcntl.LOCK_UN)
        os.close(lock_fd)
```

### Full Processing Lock

`cmd_process_queue()` now holds the lock for the entire processing cycle:

1. Acquire exclusive lock
2. Read queue file
3. Process all UUIDs
4. Write back only failed UUIDs
5. Release lock

This prevents:
- Concurrent processors duplicating work
- Lost entries from hooks adding while processing

### Service Consolidation

Changed from shell script to Python processor:

```nix
script = ''
  exec ${vikunjaSync}/bin/vikunja-direct process-queue
'';
```

This eliminates the dual-implementation issue (shell vs Python).

## Verification

- [x] Python syntax valid
- [x] NixOS rebuild successful
- [x] Lock file created on queue operations
- [x] Service consolidated to Python
