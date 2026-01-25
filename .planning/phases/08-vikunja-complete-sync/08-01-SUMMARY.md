---
phase: 08-vikunja-complete-sync
plan: 01
type: summary
---

# Summary: Project Field Sync

**Fixed project moves - changing a task's project in Taskwarrior now correctly moves it in Vikunja.**

## Accomplishments

- Added `project_id` parameter to `tw_to_vikunja_task()` function
- Updated `push_to_vikunja()` to pass resolved `project_id` to conversion
- Project ID now included in both create AND update API payloads
- Added `test-project-move` CLI command for manual verification

## Files Modified

- `pkgs/vikunja-sync/vikunja-direct.py`
  - `tw_to_vikunja_task()` - Added optional `project_id` parameter
  - `push_to_vikunja()` - Now passes `project_id` to conversion function
  - Added `cmd_test_project_move()` for testing project moves
  - Updated `main()` with new command dispatch

## Technical Details

The bug was that `project_id` was only set when creating new tasks (line 598), not when updating existing tasks. The `tw_to_vikunja_task()` function didn't include `project_id` in its return dict.

Fix: Added `project_id` as an optional parameter to `tw_to_vikunja_task()`, which conditionally includes it in the returned dict. The `push_to_vikunja()` function now passes the already-resolved `project_id` to the conversion function, ensuring project moves are synced on updates.

## Verification

- [x] Python syntax valid
- [x] `project_id` included in update payloads
- [x] Test command available: `vikunja-direct test-project-move <uuid> <project>`

## Next Step

Ready for 08-02-PLAN.md (Description & Status Sync)
