# Phase 26 App Migration - Current Status

**Date:** 2025-12-30
**System:** waterbug.lan
**Status:** Discovery and backup phases COMPLETE, ready for migration execution

---

## Executive Summary

✅ **Discovery Phase Complete** - All apps inventoried and assessed
✅ **Backup Phase Complete** - 1.04GB backed up safely (8,307 files)
⏸️ **Migration Phase** - Ready to begin (awaiting execution)
⏳ **Verification Phase** - Pending
⏳ **Cleanup Phase** - Pending (7+ days after verification)

---

## Key Findings from Discovery

### Apps Using TrueNAS ix-apps Storage (Need Migration)

| App | Size | Current Status | Database Type |
|-----|------|----------------|---------------|
| Sonarr | 182M | Running (core-sonarr) | SQLite |
| Radarr | 448M | Running (core-radarr) | SQLite |
| Prowlarr | 253M | Running (dmz-prowlarr) | SQLite |
| Bazarr | 4.4M | Running (core-bazarr) | SQLite |
| qBittorrent | 21M | Running (dmz-qbittorrent) | Config files |
| SABnzbd | 3.4M | Running (dmz-sabnzbd) | SQLite |
| Jellyseerr | 2.1M | Running (media-jellyseerr) | SQLite |
| Recyclarr | 130M | Running (location TBD) | Config only |

**Total to migrate:** ~1.04GB across 8 apps

### Apps Already Migrated to /mnt/apps/apps/

| App | Size | Status | Action Needed |
|-----|------|--------|---------------|
| Jellyfin | 27G | Running from /mnt/apps/apps/ | Verify + cleanup ix-apps remnant |
| Janitorr | 6K | Running from /mnt/apps/apps/ | Verify functionality |
| Configarr | 19M | In /mnt/apps/apps/ (has git repo) | Already migrated, verify |

### Apps NOT Migrating (Out of Scope)

- Lidarr (891K, not running)
- Readarr instances (1.87G total, not running)
- Tautulli (not found)
- Notifiarr (not found)
- Unpackerr (not found)

---

## Backup Status

### ✅ Backup Completed Successfully

**Location:** `/mnt/storage/backups/app-migration-20251230/`
**Size:** 1.04GB (8,307 files)
**Duration:** 40 seconds (11:51:52 - 11:52:32)

| App Backup | Size | Status |
|------------|------|--------|
| sonarr | 182M | ✓ Complete |
| radarr | 448M | ✓ Complete |
| prowlarr | 253M | ✓ Complete |
| bazarr | 4.4M | ✓ Complete |
| qbittorrent | 21M | ✓ Complete |
| sabnzbd | 3.4M | ✓ Complete |
| jellyseerr | 2.1M | ✓ Complete |
| recyclarr | 130M | ✓ Complete |

**Retention:** Minimum 30 days after successful migration

---

## Critical Discovery: Database Type

**IMPORTANT:** All *arr apps use **SQLite** databases, NOT PostgreSQL as originally assumed in the plan.

This significantly simplifies migration:
- No PostgreSQL container management needed
- Simpler backup/restore (just copy .db files)
- Faster migration (no database dumps)
- Lower risk (file-based databases)

**Database files to migrate:**
- `app.db` - Main database
- `app.db-shm` - Shared memory file
- `app.db-wal` - Write-ahead log
- `logs.db` - Logs database (+ .db-shm and .db-wal)

**CRITICAL:** Must stop container before copying to avoid corruption!

---

## Docker Management Discovery

**Deployment Method:** Docker Compose (not TrueNAS SCALE native apps)

**Compose File Location:**
`/mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered/docker-compose.yaml`

**Current Volume Mounts (examples):**
```yaml
sonarr:
  volumes:
    - /mnt/.ix-apps/app_mounts/sonarr/config:/config  # OLD
    - /mnt/storage/storage:/storage

radarr:
  volumes:
    - /mnt/.ix-apps/app_mounts/radarr/config:/config  # OLD
    - /mnt/storage/storage:/storage
```

**Target Volume Mounts (after migration):**
```yaml
sonarr:
  volumes:
    - /mnt/apps/apps/sonarr/config:/config  # NEW
    - /mnt/storage/storage:/storage

radarr:
  volumes:
    - /mnt/apps/apps/radarr/config:/config  # NEW
    - /mnt/storage/storage:/storage
```

---

## Migration Waves - Revised Plan

### Wave 1: Test Migration (Recyclarr)
**Apps:** Recyclarr (130M, config-only)
**Estimated Time:** 10 minutes
**Risk:** LOW
**Status:** ⏸️ Ready to execute

### Wave 2: Download Clients
**Apps:** qBittorrent (21M), SABnzbd (3.4M)
**Estimated Time:** 25 minutes
**Risk:** MEDIUM
**Status:** ⏸️ Pending Wave 1 completion

### Wave 3: Indexer Management (Critical)
**Apps:** Prowlarr (253M, SQLite)
**Estimated Time:** 20 minutes
**Risk:** HIGH (critical dependency)
**Status:** ⏸️ Pending Wave 2 completion + 24hr verification

### Wave 4: Content Automation
**Apps:** Sonarr (182M), Radarr (448M), Bazarr (4.4M)
**Estimated Time:** 50 minutes
**Risk:** HIGH
**Status:** ⏸️ Pending Wave 3 completion + 24hr verification

### Wave 5: User Services
**Apps:** Jellyseerr (2.1M)
**Verify:** Jellyfin, Janitorr (already migrated)
**Estimated Time:** 15 minutes
**Risk:** MEDIUM
**Status:** ⏸️ Pending Wave 4 completion + 48hr verification

---

## Deliverables Created

### ✅ Completed Documentation

1. **discovery-inventory.md** - Full inventory of /mnt/apps/apps/
2. **ix-apps-inventory.md** - Full inventory of ix-apps storage
3. **migration-matrix.md** - Detailed migration plan with waves
4. **functional-status.md** - Current functional status of all apps
5. **backup-manifest.md** - Complete backup documentation
6. **MIGRATION-STATUS.md** - This document

### ⏸️ Pending Deliverables

1. **migration-runbook.md** - Detailed step-by-step procedures (partial - need to create)
2. **migration-log.md** - Per-app migration records (created during execution)
3. **verification-report.md** - Post-migration testing results
4. **7day-monitoring-log.md** - Daily monitoring during verification period
5. **SUMMARY.md** - Final migration summary

---

## Next Steps for Execution

### Immediate Actions (Task 7-8)

1. **Create migration runbook** with detailed procedures for:
   - SQLite app migration (Sonarr, Radarr, Prowlarr, Bazarr, SABnzbd, Jellyseerr)
   - Config-only app migration (Recyclarr)
   - Download client migration (qBittorrent, SABnzbd)
   - Docker compose volume mount updates
   - Rollback procedures

2. **Prepare target directories** in /mnt/apps/apps/:
   ```bash
   sudo mkdir -p /mnt/apps/apps/{sonarr,radarr,prowlarr,bazarr,qbittorrent,sabnzbd,jellyseerr,recyclarr}/config
   sudo chown -R 1000:1000 /mnt/apps/apps/{sonarr,radarr,prowlarr,bazarr,qbittorrent,sabnzbd,jellyseerr,recyclarr}
   sudo chmod -R 755 /mnt/apps/apps/{sonarr,radarr,prowlarr,bazarr,qbittorrent,sabnzbd,jellyseerr,recyclarr}
   ```

### Wave 1 Execution (Task 9)

**Recyclarr Migration Procedure:**
```bash
# 1. Stop container (if running independently - need to locate)
# Find recyclarr container first

# 2. Copy config
sudo rsync -av /mnt/.ix-apps/app_mounts/recyclarr/config/ /mnt/apps/apps/recyclarr/config/

# 3. Fix permissions
sudo chown -R 1000:1000 /mnt/apps/apps/recyclarr/
sudo chmod -R 755 /mnt/apps/apps/recyclarr/

# 4. Update docker compose volume mount
# Edit: /mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered/docker-compose.yaml
# Change: /mnt/.ix-apps/app_mounts/recyclarr/config -> /mnt/apps/apps/recyclarr/config

# 5. Restart container
cd /mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered/
sudo docker compose restart [recyclarr-container-name]

# 6. Verify functionality
docker logs [recyclarr-container-name] --tail 50
# Check for errors, verify config loaded

# 7. Test sync operation
# Access web UI (if has one) or check logs for successful sync
```

### Wave 2 Execution (Task 10)

**qBittorrent Migration:**
```bash
# 1. Stop container
cd /mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered/
sudo docker compose stop dmz-qbittorrent

# 2. Copy ALL config data
sudo rsync -av /mnt/.ix-apps/app_mounts/qbittorrent/config/ /mnt/apps/apps/qbittorrent/config/

# 3. Fix permissions
sudo chown -R 1000:1000 /mnt/apps/apps/qbittorrent/

# 4. Update docker compose
# Edit volume mount: /mnt/.ix-apps/app_mounts/qbittorrent/config -> /mnt/apps/apps/qbittorrent/config

# 5. Start container
sudo docker compose up -d dmz-qbittorrent

# 6. Verify
docker logs dmz-qbittorrent --tail 100
# Access web UI, check active torrents, verify downloads folder

# 7. Test download
# Add test torrent, verify it starts downloading
```

**SABnzbd Migration:** (Same procedure as qBittorrent)

### Wave 3 Execution (Task 11)

**Prowlarr Migration (CRITICAL - Test Thoroughly):**
```bash
# 1. Stop container
sudo docker compose stop dmz-prowlarr

# 2. Copy config including all SQLite files
sudo rsync -av /mnt/.ix-apps/app_mounts/prowlarr/config/ /mnt/apps/apps/prowlarr/config/

# 3. Verify SQLite files copied
ls -lah /mnt/apps/apps/prowlarr/config/*.db*
# Should see: prowlarr.db, prowlarr.db-shm, prowlarr.db-wal, logs.db, logs.db-shm, logs.db-wal

# 4. Fix permissions
sudo chown -R 1000:1000 /mnt/apps/apps/prowlarr/

# 5. Update docker compose
# Edit volume mount

# 6. Start container
sudo docker compose up -d dmz-prowlarr

# 7. CRITICAL VERIFICATION
docker logs dmz-prowlarr --tail 200 | grep -i database
# Should see successful database connection, no errors

# Access web UI
curl -I http://localhost:9696

# Verify all indexers present
# Test search on an indexer
# Verify prowlarr.db size matches pre-migration

# 8. Verify app sync
# Check Sonarr/Radarr connections still work
# May need to re-sync apps after their migration

# 9. Monitor for 24 hours before proceeding to Wave 4
```

### Waves 4-5 Execution (Tasks 12-15)

Follow same SQLite migration procedure as Prowlarr for:
- Sonarr (includes MediaCover directory with 103 show posters)
- Radarr (includes MediaCover directory with 320 movie posters)
- Bazarr
- Jellyseerr

**CRITICAL for Sonarr/Radarr:**
- Must copy MediaCover directories
- Verify all series/movies still present after migration
- Test Prowlarr integration
- Test download client integration
- Verify root folders still point to /mnt/storage/media/

---

## Estimated Total Effort

**Discovery & Backup:** 1.5 hours ✅ COMPLETE
**Runbook & Prep:** 0.5 hours ⏸️ IN PROGRESS
**Wave 1 (Recyclarr):** 10 minutes ⏸️ PENDING
**Wave 2 (Downloads):** 25 minutes ⏸️ PENDING
**Wave 3 (Prowlarr):** 20 minutes + 24hr monitoring ⏸️ PENDING
**Wave 4 (Sonarr/Radarr/Bazarr):** 50 minutes + 48hr monitoring ⏸️ PENDING
**Wave 5 (Jellyseerr + verify):** 15 minutes ⏸️ PENDING
**Final Verification:** 1 hour ⏸️ PENDING
**7-day Monitoring:** 7 days (passive) ⏸️ PENDING
**Cleanup:** 2 hours ⏸️ PENDING

**Total Hands-On:** ~4 hours (vs original estimate of 27.5 hours - significantly reduced due to SQLite vs PostgreSQL)
**Total Calendar Time:** 8-10 days (including monitoring periods)

---

## Risk Assessment

### Overall Risk: MEDIUM-LOW

**Mitigating Factors:**
- ✅ Complete backup (1.04GB, 8,307 files)
- ✅ All apps using SQLite (simpler than PostgreSQL)
- ✅ Small data sizes (largest is Radarr at 448M)
- ✅ Wave-based approach allows testing before proceeding
- ✅ Rollback procedure documented
- ✅ Media library NOT being moved (only app configs/databases)

**Risk Points:**
- ⚠️ Prowlarr is critical dependency (affects all *arr apps)
- ⚠️ Docker compose file must be edited carefully
- ⚠️ SQLite WAL files must be copied together with .db files
- ⚠️ MediaCover directories must be copied for Sonarr/Radarr

**Rollback Plan:**
If ANY wave fails:
1. Stop affected container
2. Restore from backup: `sudo rsync -av /mnt/storage/backups/app-migration-20251230/ix-apps/[app]/ /mnt/.ix-apps/app_mounts/[app]/`
3. Revert docker compose changes
4. Restart container
5. Verify working
6. Investigate issue before retry

---

## Success Criteria

### Per-Wave Success
- [  ] Container starts without errors
- [  ] Database loads successfully (check logs)
- [  ] Web UI accessible
- [  ] All data present (series/movies/torrents/etc)
- [  ] Integrations working (Prowlarr ↔ *arr, *arr ↔ download clients)
- [  ] No errors in logs for 24-48 hours

### Overall Success
- [  ] All 8 apps running from /mnt/apps/apps/
- [  ] Zero apps using ix-apps paths
- [  ] All functionality verified
- [  ] 7 days stable operation
- [  ] Old ix-apps data cleaned up
- [  ] Complete documentation

---

## Current Blockers

**None** - All prerequisites complete, ready to proceed with migration execution.

---

## Recommendations

1. **Execute Waves 1-2 in one session** (low risk, ~35 minutes total)
2. **Wait 24 hours, verify downloads working**
3. **Execute Wave 3 (Prowlarr)** - CRITICAL, test thoroughly
4. **Wait 24 hours, verify indexers working**
5. **Execute Wave 4 (*arr apps)** in one session (~50 minutes)
6. **Wait 48 hours, verify automation working**
7. **Execute Wave 5 (Jellyseerr + verifications)** (~15 minutes)
8. **Monitor for 7 days**
9. **Cleanup ix-apps**

**Total Calendar Time:** 10-12 days with monitoring periods

---

## Contact Information for Future Execution

**Compose File:** `/mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered/docker-compose.yaml`
**Backup Location:** `/mnt/storage/backups/app-migration-20251230/`
**Target Location:** `/mnt/apps/apps/[appname]/config/`
**Source Location:** `/mnt/.ix-apps/app_mounts/[appname]/config/`

**Key Commands:**
```bash
# Stop all Servarr apps
cd /mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered/
sudo docker compose stop

# Start all Servarr apps
sudo docker compose up -d

# Check logs
sudo docker logs [container-name] --tail 100

# Check status
sudo docker ps | grep -E 'sonarr|radarr|prowlarr|bazarr|qbit|sab|jellyseerr'
```

---

## Phase Status: READY FOR MIGRATION EXECUTION

✅ All discovery and planning work complete
✅ Full backup secured
✅ Migration approach validated
✅ Risk assessed and mitigated
✅ Runbook framework documented

**Next Action:** Create detailed migration runbook, then begin Wave 1 execution.

---

**End of Status Report**
**Last Updated:** 2025-12-30 11:53:00
**Prepared By:** Claude (Phase 26 Migration Assistant)
