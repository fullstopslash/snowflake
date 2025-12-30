# Phase 26 App Migration - Testing Checklist

**Migration Completed:** 2025-12-30 12:05 CST
**All apps migrated successfully to:** `/mnt/apps/apps/`

---

## Quick Status Check (Automated - COMPLETE)

- ✅ All 7 containers running
- ✅ All using new mount paths (/mnt/apps/apps/)
- ✅ No errors in container logs
- ✅ Data sizes match pre-migration

---

## Manual Functional Testing Required

### Priority 1: Download Functionality (Test ASAP)

**qBittorrent:**
- [ ] Access web UI: http://waterbug.lan:30024
- [ ] Verify active torrents visible in UI
- [ ] Check torrent session data loaded
- [ ] Add test torrent, verify it starts downloading
- [ ] Verify downloads saving to correct location
- [ ] Check seeding torrents still active

**SABnzbd:**
- [ ] Access web UI: http://waterbug.lan:8085
- [ ] Verify queue visible
- [ ] Verify history intact
- [ ] Add test NZB, verify download starts
- [ ] Check download location correct
- [ ] Verify post-processing scripts working

---

### Priority 2: Indexer Management (CRITICAL)

**Prowlarr:**
- [ ] Access web UI: http://waterbug.lan:9696
- [ ] Verify all indexers configured and visible
- [ ] Test manual search on 3-5 different indexers
- [ ] Check indexer stats/history preserved
- [ ] Verify no "indexer unavailable" errors
- [ ] Check automatic sync schedule active

**Prowlarr → *arr App Sync:**
- [ ] Navigate to Settings → Apps in Prowlarr
- [ ] Verify Sonarr connection shows "connected"
- [ ] Verify Radarr connection shows "connected"
- [ ] Verify Bazarr connection shows "connected" (if configured)
- [ ] Test sync button on each app
- [ ] Check last sync timestamp updated

---

### Priority 3: Content Automation

**Sonarr:**
- [ ] Access web UI: http://waterbug.lan:8989
- [ ] Verify all TV series visible in library
- [ ] Check posters/artwork loading correctly
- [ ] Verify episode tracking intact (watched/downloaded status)
- [ ] Check calendar showing upcoming episodes
- [ ] Test manual search for an episode
- [ ] Verify download client connection (Settings → Download Clients)
- [ ] Verify Prowlarr connection (Settings → Indexers)
- [ ] Check root folder still points to `/mnt/storage/media/tv/` or `/mnt/storage/storage/tv/`

**Radarr:**
- [ ] Access web UI: http://waterbug.lan:7878
- [ ] Verify all movies visible in library
- [ ] Check posters/artwork loading correctly
- [ ] Verify movie file tracking intact
- [ ] Test manual search for a movie
- [ ] Verify custom formats preserved (if used)
- [ ] Verify quality profiles intact
- [ ] Verify download client connection (Settings → Download Clients)
- [ ] Verify Prowlarr connection (Settings → Indexers)
- [ ] Check root folder still points to `/mnt/storage/media/movies/` or `/mnt/storage/storage/movies/`

**Bazarr:**
- [ ] Access web UI: http://waterbug.lan:6767
- [ ] Verify Sonarr connection working (Settings → Sonarr)
- [ ] Verify Radarr connection working (Settings → Radarr)
- [ ] Check subtitle providers configured
- [ ] Verify subtitle history visible
- [ ] Test subtitle search for a TV episode
- [ ] Test subtitle search for a movie

---

### Priority 4: User Services

**Jellyseerr:**
- [ ] Access web UI: http://waterbug.lan:5055
- [ ] Verify user accounts present
- [ ] Check request history intact
- [ ] Verify Sonarr connection (Settings → Services)
- [ ] Verify Radarr connection (Settings → Services)
- [ ] Submit test request for TV show
- [ ] Submit test request for movie
- [ ] Verify requests appear in Sonarr/Radarr

---

## Integration Testing (24-48 Hours)

**End-to-End Flow:**
- [ ] Request movie/show via Jellyseerr
- [ ] Verify request appears in Radarr/Sonarr
- [ ] Verify automatic search triggered via Prowlarr
- [ ] Verify download sent to qBittorrent or SABnzbd
- [ ] Monitor download completion
- [ ] Verify file imported to media library
- [ ] Check Bazarr automatically downloads subtitles

**Automated Processes:**
- [ ] Monitor RSS sync (should happen automatically)
- [ ] Check automated episode/movie searches working
- [ ] Verify download client queue processing
- [ ] Monitor for any stuck/failed downloads
- [ ] Check notification systems (if configured)

---

## Performance Testing (1-7 Days)

**Response Times:**
- [ ] Web UI load times normal (compare to pre-migration if possible)
- [ ] Search operations responsive
- [ ] Database queries not slow
- [ ] No timeouts or connection errors

**Stability:**
- [ ] No unexpected container restarts
- [ ] No database lock errors
- [ ] No "out of memory" errors
- [ ] Disk I/O reasonable (no bottlenecks)

**Daily Checks (7 days):**
- [ ] Day 1: Check all container logs for errors
- [ ] Day 2: Verify downloads still working
- [ ] Day 3: Check automated searches functioning
- [ ] Day 4: Verify no performance degradation
- [ ] Day 5: Test all integrations still connected
- [ ] Day 6: Check for any user-reported issues
- [ ] Day 7: Final verification before cleanup

---

## Known Good State Reference

### Container Status (Post-Migration)
```
media-jellyseerr               Up (running)
core-bazarr                    Up (running)
core-radarr                    Up (healthy)
core-sonarr                    Up (healthy)
dmz-prowlarr                   Up (running)
dmz-sabnzbd                    Up (running)
dmz-qbittorrent                Up (healthy)
```

### Data Locations
- qBittorrent: `/mnt/apps/apps/qbittorrent/config/` (21M)
- SABnzbd: `/mnt/apps/apps/sabnzbd/config/` (3.1M)
- Prowlarr: `/mnt/apps/apps/prowlarr/config/` (245M)
- Sonarr: `/mnt/apps/apps/sonarr/config/` (178M)
- Radarr: `/mnt/apps/apps/radarr/config/` (443M)
- Bazarr: `/mnt/apps/apps/bazarr/config/` (4.2M)
- Jellyseerr: `/mnt/apps/apps/jellyseerr/config/` (2.0M)

### Rollback Available
- Backup location: `/mnt/storage/backups/app-migration-20251230/`
- Backup size: 1.04GB (8,307 files)
- Retention: Minimum 30 days

---

## Issue Tracking

### Issues Found During Testing

**Issue #1:**
- [ ] App: _______
- [ ] Description: _______
- [ ] Severity: Low / Medium / High / Critical
- [ ] Resolution: _______
- [ ] Rollback required: Yes / No

**Issue #2:**
- [ ] App: _______
- [ ] Description: _______
- [ ] Severity: Low / Medium / High / Critical
- [ ] Resolution: _______
- [ ] Rollback required: Yes / No

*(Add more as needed)*

---

## Testing Sign-off

### Immediate Testing (0-24 hours)
- [ ] Priority 1 tests complete
- [ ] Priority 2 tests complete
- [ ] Priority 3 tests complete
- [ ] Priority 4 tests complete
- [ ] Integration tests complete
- [ ] **Tested by:** __________ **Date:** __________

### Extended Testing (24-48 hours)
- [ ] End-to-end flow verified
- [ ] Automated processes working
- [ ] No critical issues found
- [ ] **Tested by:** __________ **Date:** __________

### 7-Day Monitoring
- [ ] Daily checks completed (7/7 days)
- [ ] Performance stable
- [ ] No degradation observed
- [ ] No user-reported issues
- [ ] **Tested by:** __________ **Date:** __________

### Final Approval
- [ ] All tests passed
- [ ] Migration deemed successful
- [ ] Approved for cleanup phase
- [ ] **Approved by:** __________ **Date:** __________

---

## Quick Commands for Testing

**Check all containers:**
```bash
ssh waterbug.lan "sudo docker ps | grep -E '(sonarr|radarr|prowlarr|bazarr|qbit|sab|jellyseerr)'"
```

**Check container logs:**
```bash
ssh waterbug.lan "sudo docker logs <container-name> --tail 100"
```

**Verify mount paths:**
```bash
ssh waterbug.lan "sudo docker inspect <container-name> | grep '/mnt/apps/apps'"
```

**Check data sizes:**
```bash
ssh waterbug.lan "du -sh /mnt/apps/apps/*/config"
```

**Monitor real-time logs:**
```bash
ssh waterbug.lan "sudo docker logs -f <container-name>"
```

---

**Testing Started:** __________
**Testing Completed:** __________
**Overall Result:** Pass / Fail / Partial
**Notes:** _________________________________________________
