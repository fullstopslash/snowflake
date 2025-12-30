# Phase 26: TrueNAS App Migration - Overview

## Quick Status

**Phase:** Discovery & Backup ✅ COMPLETE | Migration ⏸️ READY
**Date:** 2025-12-30
**System:** waterbug.lan

---

## What's Been Done

### ✅ Phase 1: Discovery (100% Complete)

- **Inventoried** /mnt/apps/apps/ - found 38 apps, NONE of target Servarr stack
- **Inventoried** ix-apps - found all 8 target Servarr apps need migration
- **Discovered** apps use SQLite (NOT PostgreSQL) - simpler migration!
- **Identified** Docker Compose deployment structure
- **Assessed** functional status of all apps

**Key Files:**
- `discovery-inventory.md` - What's in /mnt/apps/apps/
- `ix-apps-inventory.md` - What's in ix-apps storage
- `functional-status.md` - Current app status

### ✅ Phase 2: Planning (100% Complete)

- **Created** migration priority matrix with 5 waves
- **Assessed** risks and mitigations
- **Estimated** effort: ~4 hours hands-on (vs 27.5 hours originally planned)
- **Defined** success criteria per wave

**Key Files:**
- `migration-matrix.md` - Detailed wave-by-wave plan

### ✅ Phase 3: Backup (100% Complete)

- **Backed up** all 8 apps (1.04GB, 8,307 files)
- **Duration:** 40 seconds
- **Location:** `/mnt/storage/backups/app-migration-20251230/`
- **Verified** backup integrity

**Key Files:**
- `backup-manifest.md` - Complete backup documentation

---

## What's Ready to Do

### ⏸️ Next: Prepare for Migration

**Task 7-8: Create runbook and prepare directories** (~30 minutes)

1. Create detailed migration runbook (partially done in MIGRATION-STATUS.md)
2. Create target directories in /mnt/apps/apps/
3. Set correct permissions (1000:1000)

### ⏸️ Then: Execute Migrations

**Wave 1:** Recyclarr (10 min)
**Wave 2:** qBittorrent, SABnzbd (25 min)
**Wave 3:** Prowlarr (20 min + 24hr monitoring) 🔴 CRITICAL
**Wave 4:** Sonarr, Radarr, Bazarr (50 min + 48hr monitoring)
**Wave 5:** Jellyseerr + verify Jellyfin/Janitorr (15 min)

**Total hands-on:** ~2 hours migration + 1 hour verification = 3 hours
**Total calendar:** 8-10 days with monitoring periods

---

## Apps to Migrate

### Need Migration (8 apps, 1.04GB total)

| App | Size | Database | Priority | Wave |
|-----|------|----------|----------|------|
| Recyclarr | 130M | Config only | LOW | 1 |
| qBittorrent | 21M | Config + session | HIGH | 2 |
| SABnzbd | 3.4M | SQLite | HIGH | 2 |
| Prowlarr | 253M | SQLite | CRITICAL | 3 |
| Sonarr | 182M | SQLite | HIGH | 4 |
| Radarr | 448M | SQLite | HIGH | 4 |
| Bazarr | 4.4M | SQLite | MEDIUM | 4 |
| Jellyseerr | 2.1M | SQLite | MEDIUM | 5 |

### Already Migrated (Verify Only)

- Jellyfin (27G) - ✓ Using /mnt/apps/apps/
- Janitorr (6K) - ✓ Using /mnt/apps/apps/
- Configarr (19M) - ✓ Using /mnt/apps/apps/

### Skipping (Not in Use)

- Lidarr (891K) - Not running
- Readarr instances (1.87G) - Not running

---

## Key Discoveries

### 🎉 Good News

1. **SQLite, not PostgreSQL!** - All *arr apps use SQLite databases
   - Simpler migration (just copy files)
   - No database dumps needed
   - Lower risk

2. **Small data sizes** - Total migration only 1.04GB
   - Largest is Radarr at 448M
   - Fast to backup and migrate

3. **Already migrated** - Jellyfin (27G), Janitorr, Configarr already done
   - Just need verification

### ⚠️ Important Notes

1. **SQLite WAL files** - Must copy .db, .db-shm, .db-wal together
2. **MediaCover directories** - Sonarr (103 posters), Radarr (320 posters) must be copied
3. **Docker Compose** - Apps managed via compose file at:
   `/mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered/docker-compose.yaml`
4. **Prowlarr is critical** - Central dependency for all *arr apps, test thoroughly

---

## Documentation Files

All documentation in: `/home/rain/nix-config/.planning/phases/26-app-migration/`

### Completed
- ✅ `discovery-inventory.md` - /mnt/apps/apps/ inventory
- ✅ `ix-apps-inventory.md` - ix-apps storage inventory
- ✅ `migration-matrix.md` - Wave-by-wave migration plan
- ✅ `functional-status.md` - Current app status
- ✅ `backup-manifest.md` - Backup documentation
- ✅ `MIGRATION-STATUS.md` - **Comprehensive status report** 📋
- ✅ `README.md` - This file

### Pending (Created During Execution)
- ⏸️ `migration-runbook.md` - Step-by-step procedures (framework in STATUS)
- ⏸️ `migration-log.md` - Per-app migration records
- ⏸️ `verification-report.md` - Testing results
- ⏸️ `7day-monitoring-log.md` - Daily monitoring logs
- ⏸️ `SUMMARY.md` - Final migration summary

---

## Quick Reference

### Backup Location
```
/mnt/storage/backups/app-migration-20251230/
```

### Source Locations (Current)
```
/mnt/.ix-apps/app_mounts/[appname]/config/
```

### Target Locations (After Migration)
```
/mnt/apps/apps/[appname]/config/
```

### Docker Compose File
```
/mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered/docker-compose.yaml
```

### Key Commands
```bash
# View compose file
cat /mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered/docker-compose.yaml

# Stop all Servarr apps
cd /mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered/
sudo docker compose stop

# Start all Servarr apps
sudo docker compose up -d

# Check specific app status
sudo docker ps | grep sonarr
sudo docker logs core-sonarr --tail 100
```

---

## To Continue Migration

1. **Read MIGRATION-STATUS.md** - Comprehensive execution guide
2. **Create target directories** as documented in "Next Steps"
3. **Begin Wave 1** - Recyclarr migration
4. **Test and verify** each wave before proceeding
5. **Document results** in migration-log.md
6. **Monitor** between waves
7. **Cleanup** after 7-day verification

---

## Rollback If Needed

```bash
# For individual app
sudo rsync -av /mnt/storage/backups/app-migration-20251230/ix-apps/[app]/ /mnt/.ix-apps/app_mounts/[app]/
sudo chown -R 1000:1000 /mnt/.ix-apps/app_mounts/[app]/
cd /mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered/
sudo docker compose restart [container-name]
```

---

## Success Criteria

- [  ] All 8 apps running from /mnt/apps/apps/
- [  ] No apps using ix-apps paths
- [  ] All web UIs accessible
- [  ] All integrations working (Prowlarr ↔ *arr ↔ download clients)
- [  ] 7 days stable operation
- [  ] Old ix-apps data cleaned up
- [  ] Complete documentation

---

## Questions? Issues?

All procedures, rollback steps, and troubleshooting documented in:
- **MIGRATION-STATUS.md** - Primary execution guide
- **migration-matrix.md** - Wave details and rationale
- **backup-manifest.md** - Rollback procedures

---

**Status:** ✅ Discovery & backup complete, ⏸️ Ready for migration execution
**Last Updated:** 2025-12-30
