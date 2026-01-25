---
phase: 09-vikunja-sync-fixes
plan: 01
type: summary
---

# Summary: Deleted Task Filtering & Locking Extension

**Fixed critical issues with stale vikunja_id lookups and documented lock requirements.**

## Accomplishments

- Added `status == "deleted"` filter to `find_tw_task_by_vikunja_id()`
- Added `status == "deleted"` filter to `find_tw_task_by_description()`
- Documented lock requirement in `handle_webhook()` docstring

## Files Modified

- `pkgs/vikunja-sync/vikunja-direct.py`
  - `find_tw_task_by_vikunja_id()` - Skips deleted tasks
  - `find_tw_task_by_description()` - Skips deleted tasks
  - `handle_webhook()` - Added lock requirement documentation

## Technical Details

### Deleted Task Filtering

Before: Deleted TW tasks with `vikunja_id` annotations would match lookups, causing:
- Failed updates (trying to modify deleted tasks)
- Sync corruption when Vikunja IDs get reused

After: Both lookup functions skip tasks with `status == "deleted"`:

```python
if task.get("status") == "deleted":
    continue
```

### Lock Documentation

Added explicit documentation that `handle_webhook()` requires the caller to hold the sync lock:

```python
def handle_webhook(payload: dict) -> dict:
    """
    IMPORTANT: Caller MUST hold the sync lock (via acquire_lock()) before
    calling this function. The lock prevents race conditions where concurrent
    webhooks both read "no matching task" and create duplicates.
    """
```

## Verification

- [x] Python syntax valid
- [x] NixOS rebuild successful
- [x] `vikunja-direct diagnose` shows 0 errors
