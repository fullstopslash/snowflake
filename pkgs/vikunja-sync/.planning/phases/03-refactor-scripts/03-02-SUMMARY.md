# Phase 03-02 Summary: Refactor label-sync.py and correlate.py

## Objective
Refactor label-sync.py and correlate.py to use the shared vikunja_common module.

## Results

### Line Counts Before/After

| File | Before | After | Reduction |
|------|--------|-------|-----------|
| label-sync.py | 188 | 126 | 62 lines (33%) |
| correlate.py | 273 | 238 | 35 lines (13%) |
| **Total** | **461** | **364** | **97 lines (21%)** |

### Functions Removed

**label-sync.py (5 functions removed):**
- `get_api_token()` - replaced by `Config.from_env()`
- `api_get()` - replaced by `VikunjaClient.get()`
- `get_all_projects()` - replaced by `vikunja.get("/projects")`
- `get_project_tasks()` - replaced by `vikunja.get("/projects/{id}/tasks")`
- `get_tw_task()` - replaced by `tw.export_task()`
- `update_tw_tags()` - replaced by `tw.add_tags()`

**correlate.py (2 functions removed):**
- `get_tw_tasks()` - replaced by `tw.export_project()`
- `create_tw_task()` - replaced by `tw.add_task()` + `tw.complete_task()`

### Code Changes

**label-sync.py:**
- Added import: `from vikunja_common import Config, ConfigError, VikunjaClient, TaskwarriorClient, SyncLogger`
- Removed all urllib imports (json, os, subprocess, urllib.request, urllib.error)
- Now uses shared clients for all API and TW operations
- Uses SyncLogger for structured logging

**correlate.py:**
- Added import: `from vikunja_common import TaskwarriorClient, SyncLogger`
- Removed json and subprocess imports (kept for CalDAV-specific code: os, re, tempfile, Path)
- Uses TaskwarriorClient for all TW operations
- Uses SyncLogger for structured logging
- Retained CalDAV-specific code (unique to this script)
- Retained atomic file write pattern from Phase 1

### Verification Results

**Syntax check:** All scripts compile successfully
```
python3 -m py_compile vikunja-direct.py label-sync.py correlate.py vikunja_common.py
```

**Line counts:**
```
  521 vikunja-direct.py
  126 label-sync.py
  238 correlate.py
  325 vikunja_common.py
 1210 total
```

**Duplicate patterns check:**
```
vikunja-direct.py:1  (task import - intentional special case)
label-sync.py:0
correlate.py:0
```

The single subprocess.run in vikunja-direct.py is for `task import` which uses stdin input differently than the TaskwarriorClient methods. This is intentional and documented in the code.

### Status

- [x] label-sync.py refactored (188 -> 126 lines, target was 80-120)
- [x] correlate.py refactored (273 -> 238 lines, target was ~150)
- [x] All scripts import from vikunja_common
- [x] All scripts compile successfully
- [x] No duplicate subprocess/urlopen patterns in refactored files

### Notes

- label-sync.py is 126 lines (slightly above 120 target) due to retaining `extract_tw_uuid()` and `get_vikunja_tasks_with_labels()` which contain script-specific logic
- correlate.py is 238 lines (above 150 target) due to retaining CalDAV-specific functions (`get_caldav_items`, `load_correlations`, `save_correlations`) which are unique to this script and not suitable for the shared module
