---
phase: 01-critical-fixes
plan: 01-03-PLAN.md
status: complete
---

# Phase 01-03 Summary: Security and Reliability Fixes

## Objective
Fix credential exposure, add atomic file writes, and fix UUID regex patterns.

## Tasks Completed

### Task 1: Fix credential exposure in correlate.py
**Status:** Complete

Changed password handling from CLI argument to environment variable:
- Modified argument parsing from 4 args to 3 args (removed password)
- Added CALDAV_PASSWORD environment variable reading with proper error handling
- Updated vikunja-sync.sh to pass password via `CALDAV_PASSWORD="$caldav_pass"` prefix

**Files Modified:**
- `/home/rain/nix/pkgs/vikunja-sync/correlate.py` (lines 254-266)
- `/home/rain/nix/pkgs/vikunja-sync/vikunja-sync.sh` (line 100)

**Security Impact:** Credentials no longer visible in `ps aux` output.

### Task 2: Add atomic file writes to correlate.py
**Status:** Complete

Replaced direct file write with atomic tempfile + rename pattern:
- Added `import tempfile` to imports
- Modified `save_correlations()` function to use `tempfile.mkstemp()` + `os.rename()`
- Added cleanup on failure to remove temp file

**Files Modified:**
- `/home/rain/nix/pkgs/vikunja-sync/correlate.py` (imports and lines 112-127)

**Reliability Impact:** Prevents corrupted correlation files if process crashes during write.

### Task 3: Fix UUID regex patterns
**Status:** Complete

Updated UUID regex patterns in both files to use proper 8-4-4-4-12 format with IGNORECASE flag:

**correlate.py (line 83-87):**
```python
match = re.match(
    r"\s+([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}):\s+"
    r"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})",
    line,
    re.IGNORECASE
)
```

**label-sync.py (line 79-83):**
```python
match = re.search(
    r"uuid:\s*([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})",
    description,
    re.IGNORECASE
)
```

**Files Modified:**
- `/home/rain/nix/pkgs/vikunja-sync/correlate.py`
- `/home/rain/nix/pkgs/vikunja-sync/label-sync.py`

**Bug Fix Impact:** Prevents false positives from matching invalid strings like "----...----".

## Verification

- [x] `python3 -m py_compile correlate.py label-sync.py` - passes
- [x] `grep -n "CALDAV_PASSWORD" correlate.py vikunja-sync.sh` - confirms env var usage
- [x] Password no longer passed as CLI argument

## Files Modified

| File | Changes |
|------|---------|
| correlate.py | Added tempfile import, atomic writes, env var for password, fixed UUID regex |
| label-sync.py | Fixed UUID regex pattern |
| vikunja-sync.sh | Pass password via env var instead of CLI arg |

## Deviations
None. All tasks completed as specified in the plan.

## Next Steps
- Run `sudo nixos-rebuild test --flake .#malphas` to verify system integration
- Test credential hiding with `ps aux | grep correlate` during sync
