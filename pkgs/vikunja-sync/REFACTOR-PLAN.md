# Vikunja-Sync Refactoring Plan

## Executive Summary

Comprehensive analysis of the vikunja-sync suite revealed **12 critical issues**, **15 high-priority issues**, and significant code duplication across 4 Python files and 1 shell script. Estimated refactoring effort: **11-16 hours**.

---

## Critical Issues (Must Fix)

### 1. Subprocess Return Codes Not Checked
**File:** `vikunja-direct.py` lines 208, 236, 240
**Impact:** Task deletion/modification reported as success even when it fails
```python
# Current (broken):
subprocess.run(["task", existing_uuid, "delete"], input="yes\n", ...)
log(f"Deleted TW task: {existing_uuid}")
return {"success": True, ...}  # Always returns success!

# Fix:
result = subprocess.run(["task", existing_uuid, "delete"], input="yes\n", ...)
if result.returncode != 0:
    log(f"Failed to delete TW task {existing_uuid}: {result.stderr}")
    return {"success": False, "action": "delete_failed", "uuid": existing_uuid}
```

### 2. Tags/Labels Only Added, Never Removed
**Files:** `vikunja-direct.py` lines 234, 511-530
**Impact:** Removing a tag in TW doesn't remove the label in Vikunja (and vice versa)
```python
# Current: only adds tags
args.extend(f"+{tag}" for tag in tw_task["tags"])

# Fix: compute diff and remove missing tags
current_tags = set(existing_tw_task.get("tags", []))
new_tags = set(tw_task.get("tags", []))
for tag in new_tags - current_tags:
    args.append(f"+{tag}")
for tag in current_tags - new_tags:
    args.append(f"-{tag}")
```

### 3. Silent API Failure Masking
**File:** `label-sync.py` line 35
**Impact:** API failures return empty list, caller can't distinguish "no results" from "failed"
```python
# Current:
except URLError as e:
    print(f"API error: {e}", file=sys.stderr)
    return []  # Looks like "no labels" to caller

# Fix:
except URLError as e:
    print(f"API error: {e}", file=sys.stderr)
    return None  # Caller must check for None
```

### 4. Credential Exposure via CLI Arguments
**File:** `correlate.py` line 244, called from `vikunja-sync.sh` line 100
**Impact:** Password visible in `ps aux` output
```bash
# Current (in vikunja-sync.sh):
vikunja-sync-correlate "$project" "$CALDAV_URL" "$VIKUNJA_USER" "$caldav_pass"

# Fix: Pass via environment variable
CALDAV_PASSWORD="$caldav_pass" vikunja-sync-correlate "$project" "$CALDAV_URL" "$VIKUNJA_USER"
```

### 5. Non-Atomic Correlation File Writes
**File:** `correlate.py` lines 112-114
**Impact:** Crash during write corrupts correlation database
```python
# Current:
with open(filepath, "w") as f:
    f.write(content)

# Fix:
import tempfile
with tempfile.NamedTemporaryFile(mode="w", dir=filepath.parent, delete=False) as f:
    f.write(content)
    temp_path = f.name
os.rename(temp_path, filepath)
```

### 6. UUID Regex Too Permissive / Case-Sensitive
**Files:** `label-sync.py` line 79, `correlate.py` line 83
**Impact:** Invalid UUIDs matched, uppercase UUIDs ignored
```python
# Current:
match = re.search(r"uuid:\s*([a-f0-9-]{36})", ...)  # Matches "----...----"

# Fix:
UUID_PATTERN = re.compile(
    r"uuid:\s*([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})",
    re.IGNORECASE
)
```

---

## High-Priority Issues

### 7. No Subprocess Timeouts
**Files:** All Python files
**Impact:** Hung `task` command blocks sync forever
```python
# Fix: Add timeout to all subprocess.run() calls
subprocess.run([...], timeout=30)
```

### 8. Silent Exception Swallowing
**File:** `vikunja-direct.py` lines 155-156, 175-176, 217-218
```python
# Current:
except (subprocess.CalledProcessError, json.JSONDecodeError):
    pass
return None

# Fix:
except (subprocess.CalledProcessError, json.JSONDecodeError) as e:
    log(f"Failed to search TW tasks: {e}")
    return None
```

### 9. TOCTOU Race on Token File
**File:** `vikunja-direct.py` lines 49-50
```python
# Current:
if token_file and Path(token_file).exists():
    token = Path(token_file).read_text().strip()

# Fix:
try:
    token = Path(token_file).read_text(encoding="utf-8").strip()
except (FileNotFoundError, PermissionError) as e:
    raise ValueError(f"Cannot read token file: {e}") from e
```

### 10. Stale Label Cache
**File:** `vikunja-direct.py` line 312
**Impact:** Labels deleted in Vikunja still appear to exist
```python
# Fix: Clear cache at start of each sync operation, or add TTL
def clear_label_cache():
    global _label_cache
    _label_cache = {}
```

### 11. O(N^2) API Calls for Project Existence Check
**File:** `vikunja-sync.sh` lines 69-80
**Impact:** For N projects, fetches all projects N times
```bash
# Fix: Cache project list at start of sync_all
vikunja_projects=$(get_vikunja_projects)
# Then check against cached list instead of API call per project
```

### 12. Hook Exit Code Check Broken
**File:** `/etc/vikunja-sync-hook/on-modify-vikunja`
```bash
# Current (broken - $? is exit code of redirect, not vikunja-direct):
printf ... | vikunja-direct hook >> log 2>&1
if [[ $? -ne 0 ]]; then

# Fix:
vikunja-direct hook >> log 2>&1 <<< "$(printf ...)"
if [[ $? -ne 0 ]]; then
```

### 13. Retry Queue Never Consumed
**File:** Hook scripts write to `/tmp/vikunja-sync-queue.txt` but nothing reads it
**Fix:** Create systemd timer to process queue

### 14. Tag Merge Logic Incorrect
**File:** `label-sync.py` lines 152-161
```python
# Current: triggers update even when TW has extra tags
if new_tags != current_tags:
    merged_tags = list(current_tags | new_tags)

# Fix: Only add tags from Vikunja that TW doesn't have
tags_to_add = new_tags - current_tags
if tags_to_add:
    update_tw_tags(tw_uuid, list(tags_to_add))
```

### 15. No curl Response Validation
**File:** `vikunja-sync.sh` lines 54-55, 67-68
```bash
# Fix: Validate API responses
response=$(curl -sf ...) || die "API request failed"
echo "$response" | jq -e 'type == "array"' >/dev/null || die "Invalid response"
```

---

## DRY Violations (Medium Priority)

### Pattern 1: API Token Loading (3 implementations)
- `vikunja-direct.py:48-52`
- `label-sync.py:18-24`
- `vikunja-sync.sh:32-39`

### Pattern 2: TW Export Pattern (5+ occurrences)
```python
result = subprocess.run(["task", ..., "export"], ...)
tasks = json.loads(result.stdout) if result.stdout.strip() else []
```

### Pattern 3: Vikunja API GET (4+ occurrences)
```python
req = Request(url, headers={"Authorization": f"Bearer {token}"})
with urlopen(req, timeout=X) as resp:
    return json.loads(resp.read().decode())
```

### Pattern 4: Environment Variable for Loop Prevention
```python
env = {**os.environ, "VIKUNJA_SYNC_RUNNING": "1"}
```

---

## Refactoring Plan

### Phase 1: Create Shared Module (4-6 hours)

Create `vikunja_common.py` with:

```python
@dataclass
class Config:
    vikunja_url: str
    api_token: str
    caldav_user: str
    caldav_password: str | None = None

    @classmethod
    def from_env(cls) -> Config: ...

class VikunjaClient:
    def __init__(self, config: Config): ...
    def get(self, endpoint: str) -> dict | list | None: ...
    def put(self, endpoint: str, data: dict) -> dict | None: ...
    def post(self, endpoint: str, data: dict) -> dict | None: ...
    def get_projects(self) -> list[dict]: ...
    def get_or_create_project(self, title: str) -> int | None: ...
    def get_labels(self) -> list[dict]: ...
    def get_or_create_label(self, title: str) -> int | None: ...
    def attach_label(self, task_id: int, label_id: int) -> bool: ...
    def detach_label(self, task_id: int, label_id: int) -> bool: ...

class TaskwarriorClient:
    SYNC_ENV = {**os.environ, "VIKUNJA_SYNC_RUNNING": "1"}

    def export_all(self) -> list[dict]: ...
    def export_project(self, project: str) -> list[dict]: ...
    def export_task(self, uuid: str) -> dict | None: ...
    def modify_task(self, uuid: str, **changes) -> bool: ...
    def add_tags(self, uuid: str, tags: list[str]) -> bool: ...
    def remove_tags(self, uuid: str, tags: list[str]) -> bool: ...

class SyncLogger:
    def __init__(self, component: str): ...
    def info(self, msg: str, **context): ...
    def warning(self, msg: str, **context): ...
    def error(self, msg: str, **context): ...
```

### Phase 2: Refactor Scripts (2-3 hours)

- `vikunja-direct.py`: 691 lines → ~200 lines
- `label-sync.py`: 184 lines → ~80 lines
- `correlate.py`: 251 lines → ~150 lines

### Phase 3: Fix Critical Bugs (2-3 hours)

1. Add subprocess return code checks
2. Implement bidirectional tag/label sync (add AND remove)
3. Fix credential exposure in correlate.py
4. Add atomic file writes
5. Fix UUID regex patterns

### Phase 4: Improve Resilience (2-3 hours)

1. Add timeouts to all subprocess calls
2. Add retry logic for transient API failures
3. Replace file-age locking with flock
4. Create retry queue consumer (systemd timer)
5. Add log rotation

### Phase 5: Update Nix Packaging (1-2 hours)

```nix
let
  vikunjaCommon = pkgs.python3Packages.buildPythonPackage {
    pname = "vikunja-common";
    version = "0.1.0";
    src = ./src;
  };
in
pkgs.symlinkJoin {
  name = "vikunja-sync";
  paths = [ ... ];
}
```

---

## Implementation Order

| Priority | Issue | Est. Time |
|----------|-------|-----------|
| P0 | Fix subprocess return codes | 30 min |
| P0 | Add bidirectional tag sync | 1 hour |
| P0 | Fix credential exposure | 30 min |
| P0 | Add atomic file writes | 30 min |
| P1 | Create shared module | 4-6 hours |
| P1 | Add subprocess timeouts | 30 min |
| P1 | Fix silent exception handling | 30 min |
| P1 | Fix hook exit code check | 15 min |
| P2 | Cache API responses | 1 hour |
| P2 | Implement retry queue consumer | 1 hour |
| P2 | Add log rotation | 30 min |
| P3 | Refactor to use shared module | 2-3 hours |

**Total: 11-16 hours**

---

## Testing Checklist

After refactoring:

- [ ] Create task in TW with tags → appears in Vikunja with labels
- [ ] Create task in Vikunja with labels → appears in TW with tags
- [ ] Add tag to existing TW task → label added in Vikunja
- [ ] Remove tag from TW task → label removed in Vikunja
- [ ] Add label in Vikunja → tag added in TW
- [ ] Remove label in Vikunja → tag removed in TW
- [ ] API failure during sync → logged, queued for retry
- [ ] Concurrent modifications → no data loss
- [ ] Large task database (1000+ tasks) → completes in <30s
