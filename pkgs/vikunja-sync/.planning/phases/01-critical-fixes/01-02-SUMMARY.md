# Phase 01-02 Summary: Bidirectional Tag/Label Sync

**Status:** Completed

## One-liner
Implemented bidirectional tag/label removal so that removing a tag in TW removes the label in Vikunja (and vice versa), eliminating permanent drift between systems.

## Accomplishments

1. **Added helper functions (lines 340-369)**
   - `get_vikunja_task(config, task_id)`: Fetches current state of a Vikunja task
   - `detach_label(config, task_id, label_id)`: Removes a label from a Vikunja task via DELETE API call
   - Both include proper error handling (HTTPError, URLError)
   - detach_label treats 404 as success (label already removed)

2. **TW->Vikunja label removal in push_to_vikunja() (lines 556-573)**
   - After task update, fetches current Vikunja task state
   - Computes label diff: `current_label_titles - new_label_titles`
   - Calls detach_label() for each label to remove
   - Logs the number of detached labels

3. **Vikunja->TW tag removal in handle_webhook() (lines 228-254)**
   - Fetches existing TW task before modify
   - Computes tag diff: `tags_to_add = new - current`, `tags_to_remove = current - new`
   - Adds both `+tag` args for additions and `-tag` args for removals
   - Replaces the old code that only added tags with `+{tag}`

## Files Modified

- `/home/rain/nix/pkgs/vikunja-sync/vikunja-direct.py`

## Verification

- `python3 -m py_compile vikunja-direct.py` passed with no errors

## Issues Encountered

None.

## Next Step

User should run `nixos-rebuild` to deploy the changes, then test bidirectional tag sync:
```bash
# Test TW -> Vikunja removal
task add "bidirectional test" project:Test +tag1 +tag2
sleep 2
task <id> modify -tag1
sleep 2
# Verify in Vikunja API: task should only have tag2 label
```
