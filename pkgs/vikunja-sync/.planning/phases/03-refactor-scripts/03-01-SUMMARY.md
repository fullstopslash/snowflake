---
phase: 03-refactor-scripts
task: 03-01
status: completed
---

# Summary: Refactor vikunja-direct.py to use shared module

## Results

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Line count | 781 | 521 | -260 (33% reduction) |
| subprocess.run calls | 11 | 1 | -10 |
| urlopen calls | 8 | 0 | -8 |

## Functions Removed

The following local functions were removed and replaced with shared module equivalents:

### Config/Token Loading
- `Config` class definition (30 lines) - replaced with `Config.from_env()` from vikunja_common
- Token file reading code - now handled by Config.from_env()

### Vikunja API Functions (replaced with VikunjaClient)
- `_label_cache` global variable
- `get_all_labels(config)` - replaced with `vikunja.get_labels()`
- `get_or_create_label(config, title)` - replaced with `vikunja.get_or_create_label(title)`
- `get_vikunja_task(config, task_id)` - replaced with `vikunja.get_task(task_id)`
- `detach_label(config, task_id, label_id)` - replaced with `vikunja.detach_label(task_id, label_id)`
- `get_vikunja_project_id(config, project_title)` - replaced with `vikunja.get("/projects")`
- `create_vikunja_project(config, project_title)` - replaced with `vikunja.put("/projects", {...})`
- `get_or_create_vikunja_project(config, project_title)` - replaced with new `get_or_create_project(vikunja, title)`

### Taskwarrior Subprocess Functions (replaced with TaskwarriorClient)
- `TW_ENV` constant - replaced with `TaskwarriorClient.SYNC_ENV`
- Direct subprocess.run calls for:
  - `task export` - replaced with `tw.export_all()`, `tw.export_project()`, `tw.export_task()`
  - `task delete` - replaced with `tw.delete_task()`
  - `task done` - replaced with `tw.complete_task()`
  - `task modify` - replaced with `tw.modify_task()`

## What Was Preserved

- `log()` function - simple logging utility specific to this script
- `parse_tw_datetime()` and `parse_iso_datetime()` - datetime parsing utilities
- `vikunja_to_tw_task()` - conversion logic specific to this script
- `tw_to_vikunja_task()` - conversion logic specific to this script
- `find_tw_task_by_vikunja_id()` - refactored to use TaskwarriorClient
- `find_tw_task_by_description()` - refactored to use TaskwarriorClient
- `handle_webhook()` - main webhook handler (simplified internals)
- `push_to_vikunja()` - main push handler (simplified internals)
- `handle_tw_hook()` - TW hook handler
- `get_vikunja_task_id_from_tw()` - annotation parsing utility
- `get_or_create_project()` - simplified using VikunjaClient
- `find_vikunja_task_by_title()` - simplified using VikunjaClient
- CLI entry points: `cmd_webhook()`, `cmd_push()`, `cmd_hook()`, `main()`

## Remaining Direct Calls

1. **subprocess.run for task import** (1 occurrence) - The `task import` command requires piping JSON input, which isn't directly supported by TaskwarriorClient. This is acceptable as it's a specialized operation.

## Verification

- [x] `python3 -m py_compile vikunja-direct.py` - PASSED
- [x] Line count reduced from 781 to 521 (target: ~200-400 lines)
- [x] subprocess.run reduced from 11 to 1
- [x] urlopen reduced from 8 to 0
- [x] Imports from vikunja_common verified

## Notes

The refactoring achieved a 33% reduction in code size. The target of ~200-300 lines was not fully met because:

1. The business logic in `push_to_vikunja()` and `handle_webhook()` is inherently complex
2. The task conversion functions (`vikunja_to_tw_task`, `tw_to_vikunja_task`) contain domain-specific logic
3. CLI entry points and error handling add necessary boilerplate

The refactoring successfully eliminated all duplicated HTTP request code and most subprocess calls, significantly improving maintainability.
