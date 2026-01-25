---
phase: 09-vikunja-sync-audit
plan: 00
type: analysis
---

# Vikunja Sync Code Analysis: Potential Future Issues

This analysis identifies potential vulnerabilities, race conditions, edge cases, and architectural concerns that could cause problems in the future.

## Summary of Findings

| Category | Critical | High | Medium | Low |
|----------|----------|------|--------|-----|
| Race Conditions | 1 | 2 | 1 | - |
| Data Integrity | 1 | 1 | 2 | - |
| Error Handling | - | 1 | 2 | 1 |
| Performance | - | 1 | 2 | - |
| Architecture | - | - | 2 | 2 |

---

## Critical Issues

### 1. Concurrent Task Modification Race (CRITICAL)

**Location**: `vikunja-direct.py:260-276`, `handle_webhook()`

**Problem**: The `find_tw_task_by_vikunja_id()` function reads ALL tasks every time:
```python
def find_tw_task_by_vikunja_id(tw: TaskwarriorClient, vikunja_id: int) -> str | None:
    tasks = tw.export_all()  # Full export on every lookup!
    for task in tasks:
        for ann in task.get("annotations", []):
            if f"vikunja_id:{vikunja_id}" in ann.get("description", ""):
                return task.get("uuid")
```

When multiple webhooks arrive simultaneously:
1. Webhook A reads all tasks (t=0)
2. Webhook B reads all tasks (t=1ms)
3. Webhook A creates/modifies task (t=10ms)
4. Webhook B creates duplicate because its read was stale (t=11ms)

**Impact**: Duplicate tasks created under high webhook throughput.

**Fix Strategy**: Use file-based locking around the entire lookup+create/modify operation (partial fix exists but doesn't cover the read).

---

### 2. vikunja_id Collision on Task Recreation (CRITICAL)

**Location**: `vikunja-direct.py:523-546`, `annotate_vikunja_id()`

**Problem**: If a task is deleted in TW and then recreated with the same title in Vikunja:
1. Vikunja creates new task with new ID (e.g., 500)
2. TW has a DELETED task with `vikunja_id:500` from previous sync
3. New webhook arrives for Vikunja task 500
4. `find_tw_task_by_vikunja_id()` finds the DELETED task
5. Update fails or gets applied to deleted task

**Impact**: Sync failures, orphaned tasks.

**Fix Strategy**: The `find_tw_task_by_vikunja_id()` should filter out `status:deleted` tasks.

---

## High Priority Issues

### 3. Title-Based Fallback Creates Phantom Matches (HIGH)

**Location**: `vikunja-direct.py:270-276`, `find_tw_task_by_description()`

**Problem**: Title matching across projects is dangerous:
```python
def find_tw_task_by_description(tw: TaskwarriorClient, description: str, project: str) -> str | None:
    tasks = tw.export_project(project)
    for task in tasks:
        if task.get("description") == description:
            return task.get("uuid")
```

If two tasks have the same title in different projects (common with "TODO" or "Review"):
- User adds "Review PR" to project A
- User adds "Review PR" to project B
- Webhook for project B finds the task from project A by title

The project filter helps but the annotation race condition fix at line 307-313 only checks `event == "task.created"`, not the project match.

**Impact**: Wrong tasks get linked, annotation applied to wrong task.

**Fix Strategy**: After title match, verify the task's project matches before linking.

---

### 4. Webhook Queue Processing Has No Deduplication (HIGH)

**Location**: `vikunja-sync.nix:25-57`, `processQueueScript`

**Problem**: The shell script queue processor uses `sort -u` but the Python one in `cmd_process_queue()` uses `set(uuids)` after reading. However, new UUIDs can be added to the queue while processing is running:

```python
for uuid in set(uuids):  # Snapshot at start
    # ... processing takes time ...
    # Meanwhile, hooks may add the SAME uuid back to queue
```

**Impact**: Same task synced multiple times, potential for conflicting updates.

**Fix Strategy**: Use file locking around queue reads AND writes, or use atomic queue operations.

---

### 5. Unbounded API Retry Could Exhaust Resources (HIGH)

**Location**: `vikunja_common.py:107-137`, `_request()`

**Problem**:
```python
for attempt in range(self.max_retries):  # max_retries=3 by default
    # ...
    time.sleep(2**attempt)  # 1s, 2s, 4s backoff
```

With default settings, a failing API call blocks for 7 seconds minimum. In webhook processing, this can cause:
1. Queue buildup
2. systemd service timeout (60s)
3. Multiple concurrent retries if new webhooks trigger new services

**Impact**: Service becomes unresponsive during Vikunja outages.

**Fix Strategy**: Implement circuit breaker pattern, fail fast and queue for retry.

---

## Medium Priority Issues

### 6. Annotation Order Not Preserved (MEDIUM)

**Location**: `vikunja-direct.py:198-218`, `vikunja_to_tw_task()`

**Problem**: Annotations are created with the current timestamp:
```python
annotations.append({
    "entry": datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"),
    "description": f"vikunja_id:{vikunja_id}",
})
```

Multiple annotations created in the same second get the same timestamp. TW may reorder them, making it unpredictable which annotation is "first" when searching.

**Impact**: Minor - affects annotation display order only.

---

### 7. Label Cache Never Invalidated (MEDIUM)

**Location**: `vikunja_common.py:166-184`, `get_or_create_label()`

**Problem**: The `_label_cache` is populated once and never refreshed:
```python
if not self._label_cache:
    for label in self.get_labels():
        self._label_cache[label.get("title", "")] = label.get("id")
```

If a label is renamed or deleted in Vikunja while the sync process is running, the cache becomes stale.

**Impact**: Label sync fails silently, tasks tagged incorrectly.

**Fix Strategy**: Add TTL to cache or call `clear_label_cache()` periodically.

---

### 8. Reconciliation Lock File Race (MEDIUM)

**Location**: `vikunja-sync.nix:229`, `ExecCondition`

**Problem**:
```nix
ExecCondition = "${pkgs.bash}/bin/bash -c 'test ! -f ${stateDir}/reconcile.lock || test $(($(date +%%s) - $(stat -c %%Y ${stateDir}/reconcile.lock))) -gt 300'";
```

TOCTOU race between checking the lock file and the service starting. Two services could both pass the condition and run simultaneously.

**Impact**: Duplicate reconciliation runs, resource waste.

---

### 9. NetworkManager Dispatcher Runs as Root (MEDIUM)

**Location**: `vikunja-sync.nix:163-192`

**Problem**: The dispatcher script runs as root but uses `sudo -u ${username}` to run user commands. If sudo configuration changes, this could break.

Also, the background task spawning `&` doesn't wait for completion, so the network event could be logged as "handled" before the actual work finishes.

**Impact**: Silent failures on network recovery.

---

### 10. Hook Binary Resolution at Runtime (MEDIUM)

**Location**: `vikunja-sync.nix:313-315`, `on-add-vikunja` hook

**Problem**:
```bash
VIKUNJA_DIRECT=$(command -v vikunja-direct) || true
JAQ=$(command -v jaq) || true
TASK=$(command -v task) || true
```

If PATH doesn't include `/run/current-system/sw/bin` (unusual but possible), binaries won't be found. The fail-open behavior means sync silently fails.

**Impact**: Hooks fail silently if PATH is misconfigured.

---

## Low Priority Issues

### 11. No Validation of vikunja_id Annotation Format (LOW)

**Location**: Multiple locations

**Problem**: The regex `r"vikunja_id:(\d+)"` assumes the annotation is well-formed. A malformed annotation like `vikunja_id:abc` or `vikunja_id:` would cause issues.

**Impact**: Unlikely to occur naturally, but could be triggered by manual annotation editing.

---

### 12. Hardcoded Default Project "inbox" (LOW)

**Location**: `vikunja-direct.py:576`, `push_to_vikunja()`

**Problem**: Default project is "inbox" in code but configurable in Nix. Inconsistency if someone changes the Nix config but doesn't update env var.

**Impact**: Minor - tasks may go to wrong project.

---

### 13. correlate.py Uses CalDAV (Deprecated?) (LOW)

**Location**: `correlate.py`

**Problem**: The correlate script uses CalDAV for reading Vikunja data, but the main sync now uses direct API. This creates two code paths that could diverge.

**Impact**: Correlation repair may not work correctly with API-only workflows.

---

### 14. Webhook Provisioning Doesn't Handle API Rate Limits (LOW)

**Location**: `vikunja-webhook.nix:36-101`

**Problem**: The provisioning script iterates through all projects without rate limiting. With many projects, this could trigger API rate limits.

**Impact**: Provisioning failures with large project counts.

---

## Architecture Concerns

### A1. Two Retry Systems (ARCHITECTURE)

There are TWO different retry mechanisms:
1. `vikunja-sync-retry.py` - Python-based, uses subprocess
2. `processQueueScript` in Nix - Shell-based, inline

Both use the same queue file (`queue.txt`) but have different deduplication strategies.

**Recommendation**: Consolidate into one retry mechanism.

---

### A2. State Split Between User and System (ARCHITECTURE)

State is split between:
- User state: `~/.local/state/vikunja-sync/` (queue, logs, lock)
- System state: `/run/vikunja-webhook/` (payload queue)

This makes debugging harder and creates potential permission issues.

**Recommendation**: Consider unified state management.

---

### A3. No Idempotency Tracking (ARCHITECTURE)

Webhook events don't have idempotency keys. If the same webhook is delivered twice (network retry), it's processed twice.

**Recommendation**: Track processed webhook event IDs to ensure at-most-once processing.

---

### A4. No Health Metrics (ARCHITECTURE)

No Prometheus metrics, no structured logging for aggregation. Hard to monitor sync health at scale.

**Recommendation**: Add basic metrics (sync success/failure counts, latency histograms).

---

## Recommended Priority Order for Fixes

1. **Critical**: Fix `find_tw_task_by_vikunja_id()` to filter deleted tasks
2. **Critical**: Extend locking to cover the full read-modify-write cycle
3. **High**: Validate project match after title-based fallback
4. **High**: Add circuit breaker for API calls
5. **Medium**: Add label cache TTL or manual invalidation
6. **Medium**: Fix reconciliation lock TOCTOU

---

## Files Requiring Changes

| File | Issues |
|------|--------|
| `vikunja-direct.py` | #1, #2, #3, #6, #11, #12 |
| `vikunja_common.py` | #5, #7 |
| `vikunja-sync.nix` | #4, #8, #9, #10 |
| `vikunja-webhook.nix` | #14 |
| `correlate.py` | #13 |
| `vikunja-sync-retry.py` | A1 |

---

## Testing Recommendations

1. **Stress test**: Send 10+ webhooks for different tasks within 1 second
2. **Offline test**: Disconnect network mid-sync, verify queue integrity
3. **Delete-recreate test**: Delete task in TW, create same title in Vikunja
4. **Label rename test**: Rename label in Vikunja during active sync
5. **Concurrent modification test**: Modify same task from TW and Vikunja simultaneously
