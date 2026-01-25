---
phase: 07-vikunja-hardening
plan: 01
type: summary
---

# Summary: Queue File Hardening

## Tasks Completed

### Task 1: Add flock-based locking to processQueueScript
- Added exclusive flock locking via `util-linux` flock command
- Lock acquired at start with non-blocking mode (`flock -n`)
- Gracefully exits if another process holds the lock
- Lock file at `${stateDir}/queue.lock`

### Task 2: Convert processQueueScript to POSIX shell
- Converted all `[[ ]]` to `[ ]` POSIX test syntax
- Changed `&& \` continuation to proper `if/then` construct
- Script now fully POSIX-compliant

### Task 3: Use user-specific queue and log paths
- Created `stateDir` variable: `${homeDir}/.local/state/vikunja-sync`
- Queue file: `$STATE_DIR/queue.txt`
- Log file: `$STATE_DIR/direct.log`
- Lock file: `$STATE_DIR/queue.lock`
- Reconcile lock: `$STATE_DIR/reconcile.lock`
- Last sync timestamp: `$STATE_DIR/last-sync`
- Added tmpfiles rule to create state directory with proper permissions (0750)
- Updated NetworkManager dispatcher script to use new paths

## Verification

- [x] `nix-instantiate --parse` succeeds on both modules
- [x] Generated processQueueScript contains `flock` call
- [x] No `[[ ]]` syntax in processQueueScript
- [x] Paths reference `~/.local/state/vikunja-sync/`, not `/tmp/`
- [x] tmpfiles rule present for state directory

## Files Modified

- `roles/vikunja-sync.nix`
  - Added `stateDir` variable
  - Rewrote `processQueueScript` with flock and POSIX syntax
  - Updated tmpfiles.rules
  - Updated NetworkManager dispatcher script
  - Updated vikunja-reconcile service script
