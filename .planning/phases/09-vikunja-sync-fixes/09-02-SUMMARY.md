---
phase: 09-vikunja-sync-fixes
plan: 02
type: summary
---

# Summary: Project Validation in Title Fallback

**Added project verification to prevent cross-project phantom matches during title-based fallback.**

## Accomplishments

- Added project validation after title-based task lookup
- Tasks with mismatched projects are not linked, preventing sync corruption
- Added logging for project mismatch cases

## Files Modified

- `pkgs/vikunja-sync/vikunja-direct.py`
  - `handle_webhook()` - Added project verification before linking by title

## Technical Details

### The Fix

When the annotation race condition fix finds a task by title, it now verifies the project matches before linking:

```python
if existing_uuid and vikunja_id and event == "task.created":
    # Verify project actually matches before linking
    found_task = tw.export_task(existing_uuid)
    if found_task and found_task.get("project") == project_title:
        # Link the task
        annotate_vikunja_id(existing_uuid, vikunja_id)
    else:
        # Project mismatch - don't link, let it create a new task
        log(f"Title match {existing_uuid} has wrong project, not linking")
        existing_uuid = None
```

### Scenario Prevented

Before:
1. TW has "Review PR" in project "work"
2. User creates "Review PR" in Vikunja project "personal"
3. Webhook arrives, finds TW task by title
4. Wrong task gets linked with vikunja_id from different project

After:
1. Same scenario
2. Webhook finds TW task but project doesn't match
3. New TW task is created in correct project

## Verification

- [x] Python syntax valid
- [x] NixOS rebuild successful
- [x] Project mismatch logging implemented
