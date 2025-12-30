# Migration Priority Matrix

**Date:** 2025-12-30
**System:** waterbug.lan

## Executive Summary

Based on discovery, all target apps use **SQLite databases** (not PostgreSQL as planned). This simplifies migration significantly. Total data to migrate: **~2.7GB**. Migration can be completed in **one session** if desired, or in waves for safety.

## Revised Migration Waves (Based on Actual System)

### Wave 1: Simple Config-Only Apps (Test Migration)
**Goal:** Validate migration procedure with minimal risk

1. **Recyclarr** - 119M, config files only, no database
   - Risk: LOW (no database, not critical)
   - Downtime: 2-5 minutes
   - Migration time: 10 minutes

**Total Wave 1:** 119M, ~10 minutes

**Rationale:** Simple test case to validate rsync procedure, permission fixing, and docker-compose volume updates.

---

### Wave 2: Download Clients (Foundation Services)
**Goal:** Migrate critical download infrastructure

1. **qBittorrent** - 21M, torrent client with session data
   - Risk: MEDIUM (active torrents, but can re-add)
   - Downtime: 5-10 minutes
   - Migration time: 15 minutes
   - Note: Torrents may need to be re-checked after migration

2. **SABnzbd** - 3.2M, Usenet downloader
   - Risk: MEDIUM (download queue, history)
   - Downtime: 5 minutes
   - Migration time: 10 minutes

**Total Wave 2:** 24M, ~25 minutes

**Rationale:** Download clients are dependencies for *arr apps. Migrate before content automation apps. Can afford brief downtime without losing data (downloads may pause but will resume).

---

### Wave 3: Indexer Management (Critical Foundation)
**Goal:** Migrate central indexer management before content apps

1. **Prowlarr** - 245M, SQLite database (prowlarr.db 317M with WAL)
   - Risk: HIGH (central dependency for all *arr apps)
   - Downtime: 10-15 minutes
   - Migration time: 20 minutes
   - Database: prowlarr.db (317M), logs.db (2.4M)
   - **CRITICAL:** Must verify all indexers still configured after migration
   - **CRITICAL:** May need to re-sync with Sonarr/Radarr/etc after migration

**Total Wave 3:** 245M, ~20 minutes

**Rationale:** Prowlarr is the central indexer hub for all *arr apps. Must be working before migrating content automation. Larger database (317M) requires careful migration.

---

### Wave 4: Content Automation (*arr Stack)
**Goal:** Migrate all content automation apps

1. **Sonarr** - 178M, SQLite database for TV automation
   - Risk: HIGH (many TV shows tracked, episode history)
   - Downtime: 10-15 minutes
   - Migration time: 15 minutes
   - Database: sonarr.db (96M), logs.db (6M)
   - MediaCover: 103 show posters
   - Verify: All series present, episode tracking intact, Prowlarr connection

2. **Radarr** - 443M, SQLite database for movie automation
   - Risk: HIGH (movie library, quality profiles, custom formats)
   - Downtime: 10-15 minutes
   - Migration time: 25 minutes
   - Database: radarr.db (22M), logs.db (5M)
   - MediaCover: 320 movie posters
   - Verify: All movies present, custom formats, Prowlarr connection

3. **Bazarr** - 4.2M, SQLite database for subtitles
   - Risk: MEDIUM (subtitle history, Sonarr/Radarr integration)
   - Downtime: 5 minutes
   - Migration time: 10 minutes
   - Verify: Sonarr/Radarr connections, subtitle providers

4. **Lidarr** - 891K, SQLite database for music (NOT CURRENTLY RUNNING)
   - Risk: LOW (not actively used)
   - Downtime: N/A
   - Migration time: 5 minutes
   - Decision: Migrate or skip? Check if actually needed.

5. **Readarr instances** - Need investigation
   - readar: 997M
   - readar_ebooks: 740M
   - readar_audiobooks: 137M
   - **CRITICAL:** Determine which instance(s) are actually running
   - Migration time: 15-30 minutes depending on active instances

**Total Wave 4:** ~1.9GB (including all Readarr), ~70 minutes

**Rationale:** Core content automation stack. Migrate after download clients and Prowlarr are confirmed working. Largest data volumes but still manageable. Can migrate Readarr last or skip if not in use.

---

### Wave 5: User-Facing Services (Request & Playback)
**Goal:** Migrate user-facing request and media services

1. **Jellyfin** - Already migrated to /mnt/apps/apps/jellyfin/config/
   - Action: VERIFY migration complete
   - Check: 27G in /mnt/apps/apps/, only 2K in ix-apps
   - Verify: All libraries, metadata, user accounts, playback
   - Cleanup: Remove /mnt/.ix-apps/app_mounts/jellyfin/ after verification
   - Old install: Consider cleaning up jellyfin3 (7.2G in ix-apps)

2. **Jellyseerr** - 2.0M, SQLite database for media requests
   - Risk: MEDIUM (user request history)
   - Downtime: 5 minutes
   - Migration time: 10 minutes
   - Verify: Sonarr/Radarr connections, user accounts, request history

**Total Wave 5:** 2M new + verify 27G existing, ~10 minutes + verification

**Rationale:** User-facing services. Migrate after all automation is working so requests can be fulfilled. Jellyfin already done, just needs verification.

---

### Wave 6: Supporting Utilities
**Goal:** Migrate cleanup and utility apps

1. **Janitorr** - Already migrated to /mnt/apps/apps/janitorr/
   - Action: VERIFY migration complete
   - Check: Config file bind mount working
   - Verify: Cleanup schedules, *arr connections

**Total Wave 6:** Verification only

**Rationale:** Supporting services can be migrated last. Janitorr already done.

---

## Apps NOT Migrating (Out of Scope)

These apps are in ix-apps but not part of Servarr stack migration:
- audiobookrequest, audiobookshelf, autobrr, calibre, calibre-web
- changedetection, decluttarr, ersatztv, faster-whisper, flaresolverr
- freshrss, gluetun, homarr, huntarr, jackett, jelly-meilisearch
- jellyfin3 (old install - consider deleting)
- jellystat, kapowarr, karakeep-meili, komga, lazylibrarian
- n8n, nextcloud, nzbget (old, consider deleting), obsidian, ollama
- ombi, pihole, planka, readeck, reiverr, spottarr, stashapp
- suggestarr, syncthing, task-md, tdarr, transmission (old, delete)
- vaultwarden, wekan, whisparr, ytdl-sub

---

## Overall Migration Plan

### Option A: One-Session Migration (Aggressive)
- Total data: ~2.7GB
- Total time: ~2-3 hours including verification
- Risk: Medium (doing everything at once)
- Benefit: Done quickly, clean cutover

### Option B: Wave-Based Migration (Conservative - RECOMMENDED)
- Wave 1 (Recyclarr): Day 1, 10 min
- Wave 2 (Download clients): Day 1, 25 min
- Wave 3 (Prowlarr): Day 2, 20 min + 24hr monitoring
- Wave 4 (*arr apps): Day 3, 70 min + testing
- Wave 5 (Jellyseerr + verify Jellyfin): Day 4, 10 min + testing
- Wave 6 (Verify Janitorr): Day 4, 5 min
- Total calendar time: 4 days
- Total hands-on time: ~2.5 hours

### Option C: Hybrid (RECOMMENDED FOR THIS CASE)
Given the small data sizes and SQLite simplicity:
- **Session 1:** Waves 1+2 (Recyclarr, download clients) - 35 min
- **Wait 24 hours, verify downloads working**
- **Session 2:** Wave 3 (Prowlarr) - 20 min
- **Wait 24 hours, verify indexers working**
- **Session 3:** Wave 4 (*arr apps) - 70 min
- **Wait 48 hours, verify automation working**
- **Session 4:** Wave 5+6 (Jellyseerr, verifications) - 15 min
- **Wait 7 days, then cleanup**

---

## Risk Assessment

| Wave | Risk Level | Impact if Failed | Rollback Time | Mitigation |
|------|------------|------------------|---------------|------------|
| 1 (Recyclarr) | LOW | No automation sync | 5 min | Non-critical, easy rollback |
| 2 (Downloads) | MEDIUM | Downloads pause | 10 min | Backup configs, test restore |
| 3 (Prowlarr) | HIGH | No indexer searches | 10 min | Full backup, verify DB integrity |
| 4 (*arr apps) | HIGH | No automation | 15 min/app | Per-app backups, staged migration |
| 5 (Jellyseerr) | MEDIUM | No user requests | 5 min | Backup DB, verify user data |
| 6 (Utilities) | LOW | No cleanup jobs | 5 min | Already done, just verify |

---

## Success Criteria Per Wave

### Wave 1 Success
- [ ] Recyclarr container starts
- [ ] Config files readable
- [ ] Can sync to *arr apps
- [ ] No errors in logs

### Wave 2 Success
- [ ] qBittorrent starts and shows active torrents
- [ ] Can add new torrent and download
- [ ] SABnzbd starts and shows queue/history
- [ ] Can add new NZB and download
- [ ] Both clients accessible to *arr apps

### Wave 3 Success
- [ ] Prowlarr starts without DB errors
- [ ] All indexers still configured
- [ ] Can search indexers successfully
- [ ] prowlarr.db size matches pre-migration
- [ ] No indexer sync errors

### Wave 4 Success
- [ ] All *arr apps start without DB errors
- [ ] All tracked content present (shows/movies/music/books)
- [ ] MediaCover posters intact
- [ ] Download client connections work
- [ ] Prowlarr connections work
- [ ] Can perform manual search
- [ ] Automated searches trigger correctly

### Wave 5 Success
- [ ] Jellyfin: All libraries, metadata, users, playback working
- [ ] Jellyseerr starts without DB errors
- [ ] User accounts present
- [ ] Request history intact
- [ ] Can submit new request
- [ ] Sonarr/Radarr connections work

### Wave 6 Success
- [ ] Janitorr config loaded
- [ ] Cleanup schedules active
- [ ] *arr connections work
- [ ] Cleanup jobs execute

---

## Special Considerations

### Readarr Instances
**Investigation needed:** Determine which Readarr instance(s) are actually running:
```bash
sudo docker ps | grep -i readar
ls -la /mnt/.ix-apps/app_mounts/readar*/
```

Options:
1. If only one is running: Migrate that one
2. If multiple are running: Migrate all to separate directories (readarr-ebooks, readarr-audiobooks)
3. If none are running: Consider skipping migration or archiving

### Lidarr
**Currently not running.** Options:
1. Skip migration if not needed
2. Migrate for completeness (only 891K)
3. Archive and delete if truly unused

### Jellyfin Old Install
**jellyfin3 at 7.2G in ix-apps** - appears to be old installation.
- Action: After verifying current Jellyfin working from /mnt/apps/apps/, delete jellyfin3
- Saves: 7.2G
- Risk: LOW (not in use)

### Database Integrity
All *arr apps use SQLite with WAL (Write-Ahead Logging):
- Files: app.db, app.db-shm, app.db-wal
- **CRITICAL:** Must stop app before copying to avoid corruption
- **CRITICAL:** Copy all three files (db, db-shm, db-wal)
- Verify: Check database sizes match pre-migration

---

## Estimated Total Effort

### Hands-On Time
- Discovery & inventory: 1 hour (COMPLETE)
- Backup: 30 minutes
- Migration execution: 2.5 hours
- Verification: 1 hour
- Documentation: 1 hour
- **Total: 6 hours**

### Calendar Time (with monitoring periods)
- Week 1: Discovery, backup, Waves 1-2
- Week 2: Wave 3, wait 24hr, Wave 4, wait 48hr
- Week 3: Wave 5-6, verify Jellyfin/Janitorr
- Week 4: 7-day monitoring
- Week 5: Cleanup
- **Total: 5 weeks (but only 6 hours hands-on)**

### Comparison to Original Plan
- **Original estimate:** 27.5 hours hands-on
- **Revised estimate:** 6 hours hands-on
- **Reason:** No PostgreSQL migrations, much smaller data sizes (2.7GB vs expected 10-50GB)
