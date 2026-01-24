# Roadmap: Vikunja-Sync v1.1

## Overview

Fix critical data-corrupting bugs, create shared module to eliminate duplication, refactor all scripts to use shared code, add resilience patterns, and validate with comprehensive testing.

## Phases

- [x] **Phase 1: Critical Bug Fixes** - Fix subprocess checks, bidirectional tags, credentials, atomic writes, UUID regex
- [x] **Phase 2: Shared Module** - Create vikunja_common.py with Config, VikunjaClient, TaskwarriorClient, SyncLogger
- [x] **Phase 3: Refactor Scripts** - Migrate vikunja-direct.py, label-sync.py, correlate.py to use shared module
- [x] **Phase 4: Resilience** - Add timeouts, retries, proper error handling, retry queue consumer
- [x] **Phase 5: Testing & Validation** - End-to-end testing of all sync scenarios

## Phase Details

### Phase 1: Critical Bug Fixes
**Goal**: Fix all data-corrupting bugs that cause silent failures or data loss
**Depends on**: Nothing (first phase)
**Plans**: 3 plans

Plans:
- [x] 01-01: Fix subprocess return code checks in vikunja-direct.py
- [x] 01-02: Implement bidirectional tag/label sync (add AND remove)
- [x] 01-03: Fix credential exposure, atomic writes, UUID regex

### Phase 2: Shared Module
**Goal**: Create vikunja_common.py with reusable components
**Depends on**: Phase 1
**Plans**: 2 plans

Plans:
- [x] 02-01: Create Config dataclass and VikunjaClient class
- [x] 02-02: Create TaskwarriorClient and SyncLogger classes

### Phase 3: Refactor Scripts
**Goal**: Migrate all scripts to use shared module, reduce code by 40%+
**Depends on**: Phase 2
**Plans**: 2 plans

Plans:
- [x] 03-01: Refactor vikunja-direct.py (781 -> 521 lines, -33%)
- [x] 03-02: Refactor label-sync.py and correlate.py (-21%)

### Phase 4: Resilience
**Goal**: Add proper error handling, timeouts, and retry mechanisms
**Depends on**: Phase 3
**Plans**: 2 plans

Plans:
- [x] 04-01: Add subprocess timeouts and API retry logic
- [x] 04-02: Fix hook exit code check and implement retry queue consumer

### Phase 5: Testing & Validation
**Goal**: Verify all sync scenarios work correctly
**Depends on**: Phase 4
**Plans**: 1 plan

Plans:
- [x] 05-01: End-to-end integration testing

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Critical Bug Fixes | 3/3 | Complete | 2026-01-24 |
| 2. Shared Module | 2/2 | Complete | 2026-01-24 |
| 3. Refactor Scripts | 2/2 | Complete | 2026-01-24 |
| 4. Resilience | 2/2 | Complete | 2026-01-24 |
| 5. Testing & Validation | 1/1 | Complete | 2026-01-24 |
