# Plan: Vikunja-Sync Optimization for Native-Feel Performance

## Goal

Transform the vikunja-sync system from batch-oriented full syncs to event-driven incremental operations that feel native to the filesystem.

## Current Architecture Analysis

### Pain Points Identified

1. **Full Database Syncs on Every Trigger**
   - `vikunja-sync.sh` iterates ALL projects on every webhook/hook
   - syncall runs full comparison for entire project even for single-task changes
   - Label sync fetches ALL tasks from ALL projects every time

2. **Duplicate API Calls**
   - Projects fetched multiple times: once in vikunja-sync.sh, again in label-sync.py
   - CalDAV connections established repeatedly (correlate.py, syncall, label-sync)
   - API token read from file on every function call

3. **No Change Detection**
   - Webhook payload contains exact change info but we ignore it
   - TW on-exit hook triggers full sync instead of syncing changed task
   - No caching of last-known state to detect actual deltas

4. **Redundant Correlation Repair**
   - correlate.py runs before every sync even when correlations are stable
   - Full CalDAV calendar scan just to check for orphans

5. **Sequential Processing**
   - Projects synced one-by-one instead of parallel
   - Label sync waits for all task syncs to complete

### Current Data Flow

```
Webhook (task.created/updated/deleted)
    │
    ├─→ Ignores payload details
    │
    └─→ Triggers full sync for project
            │
            ├─→ create_vikunja_project (API call)
            ├─→ repair_correlations (full CalDAV scan)
            ├─→ tw_caldav_sync (full bidirectional diff)
            └─→ sync_labels (fetches ALL tasks from ALL projects)
```

---

## Implementation Plan

### Phase 1: Payload-Driven Incremental Sync

**Objective**: Use webhook payload to sync only the changed task

#### 1.1 Create task-level sync script

**File**: `pkgs/vikunja-sync/sync-task.py`

New script that:
- Accepts task ID and event type from webhook payload
- Fetches only the single changed task from Vikunja API
- Applies change directly to Taskwarrior without full sync
- Updates correlation cache incrementally

```
Webhook payload → extract task_id, event_type, project
    │
    ├─ task.created → fetch task → create in TW → add correlation
    ├─ task.updated → fetch task → update in TW (by correlation)
    └─ task.deleted → lookup correlation → delete from TW → remove correlation
```

#### 1.2 Update webhook trigger script

**File**: `roles/vikunja-webhook.nix`

Extract and pass webhook payload fields:
- `data.id` (task ID)
- `data.project.id` (project ID)
- `data.project.title` (project title)
- `event_name` (task.created/updated/deleted)
- `data.labels` (labels array for direct sync)

#### 1.3 Create correlation cache manager

**File**: `pkgs/vikunja-sync/correlation-cache.py`

Shared module for:
- Loading/saving correlations with locking
- Incremental add/remove operations
- Lookup by TW UUID or Vikunja task ID

**Verification**:
- Change task in Vikunja → observe only 1 API call
- Measure sync latency: target < 500ms

---

### Phase 2: TW Hook Optimization

**Objective**: Sync only the changed task from Taskwarrior

#### 2.1 Parse on-exit hook stdin

**File**: `roles/vikunja-sync.nix` (on-exit hook)

TW on-exit hook receives JSON with changed tasks on stdin:
```json
{"description":"task name","project":"projectname","uuid":"..."}
```

Extract and sync only that specific task.

#### 2.2 Create TW-to-Vikunja single-task sync

**File**: `pkgs/vikunja-sync/push-task.py`

New script that:
- Takes TW task UUID as argument
- Looks up correlation to find Vikunja task ID
- If correlated: PATCH the Vikunja task via API
- If new: POST to create task, save correlation
- Syncs labels bidirectionally for just this task

**Verification**:
- Edit task in TW CLI → observe single API call to Vikunja
- Target latency: < 300ms

---

### Phase 3: Unified API Client

**Objective**: Eliminate duplicate connections and token reads

#### 3.1 Create shared Vikunja client module

**File**: `pkgs/vikunja-sync/vikunja_client.py`

Shared module providing:
- Singleton API token loading (read once, cache)
- Connection pooling for HTTP requests
- CalDAV client factory with connection reuse
- Typed methods: `get_task()`, `update_task()`, `get_project_tasks()`, `get_labels()`

#### 3.2 Refactor existing scripts to use client

Update:
- `label-sync.py` → use `vikunja_client`
- `correlate.py` → use `vikunja_client`
- `sync-task.py` → use `vikunja_client`
- `push-task.py` → use `vikunja_client`

**Verification**:
- Single token read per sync operation
- Connection reuse visible in debug logs

---

### Phase 4: Smart Label Sync

**Objective**: Sync labels only for changed tasks

#### 4.1 Integrate labels into task-level sync

Rather than separate label-sync pass:
- `sync-task.py`: Include labels in task fetch, apply to TW
- `push-task.py`: Include TW tags in Vikunja update

#### 4.2 Remove standalone label-sync.py

After integration complete:
- Labels sync inline with task changes
- No more "sync all labels" pass

**Verification**:
- Add label in Vikunja → appears in TW within 1 second
- Add tag in TW → appears in Vikunja within 1 second

---

### Phase 5: Parallel Processing & Caching

**Objective**: Speed up full syncs (periodic/initial)

#### 5.1 Parallel project sync

**File**: `pkgs/vikunja-sync/vikunja-sync.sh`

Use GNU parallel or async Python for full syncs:
```bash
echo "$all_projects" | parallel -j4 sync_project {}
```

#### 5.2 State caching for skip-if-unchanged

**File**: `pkgs/vikunja-sync/state-cache.py`

Track last-sync timestamps per project:
- If project unchanged since last sync, skip
- Use Vikunja `updated` field as change indicator

#### 5.3 Remove correlate.py from hot path

Only run correlation repair:
- On first sync (no correlation file)
- On explicit `vikunja-sync repair` command
- When sync detects UUID collision error

**Verification**:
- Full sync of 10 projects in < 5 seconds (vs current ~30s)
- Projects with no changes: 0 API calls

---

### Phase 6: Daemon Mode (Future)

**Objective**: Persistent process for sub-100ms syncs

#### 6.1 Long-running sync daemon

**File**: `pkgs/vikunja-sync/vikunja-syncd.py`

Daemon that:
- Maintains persistent CalDAV/API connections
- Keeps correlations in memory
- Listens on Unix socket for sync requests
- Webhook/hook triggers send message to socket instead of spawning process

#### 6.2 Systemd socket activation

**File**: `roles/vikunja-sync.nix`

```nix
systemd.user.sockets.vikunja-syncd = {
  listenStreams = ["%t/vikunja-sync.sock"];
};
```

**Verification**:
- Sync latency < 100ms
- Memory usage < 50MB

---

## File Summary

| File | Action | Phase |
|------|--------|-------|
| `pkgs/vikunja-sync/sync-task.py` | Create | 1 |
| `pkgs/vikunja-sync/correlation-cache.py` | Create | 1 |
| `roles/vikunja-webhook.nix` | Modify | 1 |
| `pkgs/vikunja-sync/push-task.py` | Create | 2 |
| `roles/vikunja-sync.nix` | Modify | 2 |
| `pkgs/vikunja-sync/vikunja_client.py` | Create | 3 |
| `pkgs/vikunja-sync/label-sync.py` | Modify/Remove | 3,4 |
| `pkgs/vikunja-sync/correlate.py` | Modify | 3,5 |
| `pkgs/vikunja-sync/vikunja-sync.sh` | Modify | 5 |
| `pkgs/vikunja-sync/state-cache.py` | Create | 5 |
| `pkgs/vikunja-sync/vikunja-syncd.py` | Create | 6 |
| `pkgs/vikunja-sync/default.nix` | Modify | All |

---

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Webhook-triggered sync | ~5-10s | < 500ms |
| TW hook sync | ~5-10s | < 300ms |
| Full sync (10 projects) | ~30s | < 5s |
| API calls per single task change | ~50+ | 1-3 |
| Label sync latency | ~3s | inline |

---

## Risks & Mitigations

1. **Correlation drift**: Incremental updates could desync
   - Mitigation: Periodic full sync (existing timer) validates state

2. **Race conditions**: Concurrent syncs from webhook + hook
   - Mitigation: File locking on correlations, systemd unit collision protection

3. **API rate limits**: Parallel syncs could hit Vikunja limits
   - Mitigation: Configurable parallelism, exponential backoff

---

## Execution Order

1. **Phase 1** - Highest impact: webhook → single-task sync
2. **Phase 2** - TW hook optimization (similar pattern)
3. **Phase 3** - Foundation for code quality
4. **Phase 4** - Eliminates redundant passes
5. **Phase 5** - Full sync optimization
6. **Phase 6** - Future enhancement (optional)

Ready for implementation approval.
