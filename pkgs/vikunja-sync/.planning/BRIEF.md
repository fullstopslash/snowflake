# Vikunja-Sync Suite

**One-liner**: Bidirectional task synchronization between Taskwarrior and Vikunja via webhooks and scheduled jobs.

## Current State (Updated: 2026-01-24)

**Shipped:** v1.0 (production, running on NixOS)
**Status:** Production, actively used for daily task management
**Codebase:**
- ~1,100 lines of Python across 4 files
- 1 shell orchestration script
- NixOS module with systemd integration
- Taskwarrior hooks (on-add, on-modify)

**Known Issues (Critical):**
1. Subprocess return codes not checked - deletions/modifications report success even when they fail
2. Tags/labels only ADD, never remove - bidirectional sync is broken
3. Credential exposure via CLI arguments (visible in `ps aux`)
4. Non-atomic correlation file writes - crash corrupts database
5. UUID regex too permissive and case-sensitive
6. Silent API failure masking - can't distinguish "no results" from "failed"

**Known Issues (High):**
- No subprocess timeouts (hung `task` command blocks sync forever)
- Silent exception swallowing in multiple locations
- TOCTOU race on token file
- Stale label cache (deleted labels still appear to exist)
- Hook exit code check broken (checks redirect, not command)
- Retry queue never consumed

**DRY Violations:**
- API token loading duplicated 3 times
- TW export pattern duplicated 5+ times
- Vikunja API GET pattern duplicated 4+ times

## v1.1 Goals

**Vision:** Fix all data-corrupting bugs and eliminate code duplication to make the suite maintainable.

**Motivation:**
- Tags removed in Taskwarrior never sync to Vikunja (broken bidirectional sync)
- Silent failures cause data inconsistency between systems
- Duplicated code makes bug fixes tedious and error-prone

**Scope (v1.1):**
- Fix all 6 critical bugs (subprocess checks, bidirectional tags, credentials, atomic writes, UUID regex, API failures)
- Create shared Python module to eliminate duplication
- Add resilience (timeouts, retries, proper error handling)
- Refactor all scripts to use shared module

**Success Criteria:**
- [ ] Add tag in TW -> appears in Vikunja; remove tag in TW -> removed from Vikunja
- [ ] Add label in Vikunja -> appears in TW; remove label in Vikunja -> removed from TW
- [ ] All subprocess failures logged and properly reported (not silent)
- [ ] No credentials visible in `ps aux` output
- [ ] Code reduced by 40%+ through shared module

**Out of Scope:**
- New features (conflict resolution, UI, notifications)
- CalDAV sync changes (correlate.py CalDAV logic stays as-is)
- Hook architecture changes (keep current on-add/on-modify pattern)
