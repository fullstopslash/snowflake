# TrueNAS SCALE Application Path Audit Report

**Audit Date:** 2025-12-30
**System:** waterbug.lan
**Objective:** Verify all applications are using `/mnt/apps/apps/` paths instead of legacy `/mnt/.ix-apps/` paths

---

## Executive Summary

### Overall Statistics
- **Total Containers Analyzed:** 65
- **Apps Using `/mnt/apps/apps/`:** 36 (55.4%)
- **Apps Using `/mnt/.ix-apps/` ONLY:** 19 (29.2%)
- **Apps with Mixed Paths:** 2 (3.1%)
- **Apps with Storage Only:** 0 (0.0%)
- **Apps with No Relevant Mounts:** 8 (12.3%)

### Phase 26 Migration Status: ✅ COMPLETE
All 9 apps targeted in Phase 26 are successfully using `/mnt/apps/apps/` paths:
- qbittorrent ✅
- sabnzbd ✅
- prowlarr ✅
- sonarr ✅
- radarr ✅
- bazarr ✅
- jellyseerr ✅
- jellyfin ✅ (previously migrated)
- janitorr ✅ (previously migrated)

### Critical Findings
1. **19 apps still using ix-apps paths** - These need migration
2. **2 apps have mixed paths** - Partially migrated (media-komga, searxng)
3. **No discrepancies found** between compose files and runtime mounts
4. **Phase 26 migration verified successful** - All targeted apps correctly migrated

---

## Section 1: Apps Correctly Using /mnt/apps/apps/ (36 apps)

### Media Management Apps (10 apps)
1. **core-bazarr**
   - Config: `/mnt/apps/apps/bazarr/config -> /config`
   - Storage: `/mnt/storage/storage -> /storage`
   - Additional: Movies and TV show mounts

2. **core-radarr**
   - Config: `/mnt/apps/apps/radarr/config -> /config`
   - Storage: `/mnt/storage/storage -> /storage`

3. **core-sonarr**
   - Config: `/mnt/apps/apps/sonarr/config -> /config`
   - Storage: `/mnt/storage/storage -> /storage`

4. **dmz-prowlarr**
   - Config: `/mnt/apps/apps/prowlarr/config -> /config`

5. **media-jellyfin**
   - Config: `/mnt/apps/apps/jellyfin/config -> /config`
   - Storage: `/mnt/storage/storage -> /storage`

6. **media-jellyseerr**
   - Config: `/mnt/apps/apps/jellyseerr/config -> /app/config`

7. **media-audiobookshelf**
   - Config: `/mnt/apps/apps/audiobookshelf/config -> /config`
   - Metadata: `/mnt/apps/apps/audiobookshelf/metadata -> /metadata`
   - Storage: `/mnt/storage/storage -> /storage`

8. **ersatztv**
   - Config: `/mnt/apps/apps/ersatztv/config -> /config`
   - Storage: `/mnt/storage/storage -> /storage`

9. **jackett**
   - Config: `/mnt/apps/apps/jackett/config -> /config`
   - Storage: `/mnt/storage/storage -> /storage`

10. **media-jelly-meilisearch**
    - Entry point: `/mnt/apps/apps/jelly-meili-entry-point.sh -> /entry-point.sh`
    - Data: `/mnt/apps/apps/jelly-meilisearch -> /meili_data`

### Download Clients (2 apps)
11. **dmz-qbittorrent**
    - Config: `/mnt/apps/apps/qbittorrent/config -> /config`
    - Storage: `/mnt/storage/storage -> /storage`

12. **dmz-sabnzbd**
    - Config: `/mnt/apps/apps/sabnzbd/config -> /config`
    - Storage: `/mnt/storage/storage -> /storage`

### Automation & Monitoring (3 apps)
13. **media-janitorr**
    - Config: `/mnt/apps/apps/janitorr/config/application.yml -> /workspace/application.yml`
    - Logs: `/mnt/apps/apps/janitorr/logs -> /logs`
    - Storage: `/mnt/storage/storage -> /storage`

14. **core-checkrr**
    - Config: `/mnt/apps/apps/checkrr/config/checkrr.yaml -> /checkrr.yaml`
    - Database: `/mnt/apps/apps/checkrr/config/checkrr.db -> /checkrr.db`
    - Storage: `/mnt/storage/storage -> /storage`

15. **changedetection**
    - Data: `/mnt/apps/apps/changedetection/data -> /datastore`

### Content Apps (5 apps)
16. **media-stash**
    - Multiple mounts: metadata, cache, data, blobs, generated, config
    - Storage: `/mnt/storage/storage -> /storage`
    - Cross-reference: Uses jellyfin metadata path

17. **core-kapowarr**
    - Database: `/mnt/apps/apps/kapowarr/kapowarr-db -> /app/db`
    - Downloads: `/mnt/storage/storage/Downloads/kapowarr -> /app/temp_downloads`
    - Storage: `/mnt/storage/storage -> /storage`

18. **dmz-pinchflat**
    - Config: `/mnt/apps/apps/pinchflat/config -> /config`
    - Downloads: `/mnt/storage/storage/Downloads/pinchflat -> /downloads`

19. **readeck**
    - Data: `/mnt/apps/apps/readeck/data -> /readeck`
    - Storage: `/mnt/storage/storage -> /storage`

20. **freshrss**
    - Config: `/mnt/apps/apps/freshrss/config -> /config`

### Infrastructure Apps (9 apps)
21. **ix-portainer-portainer-1**
    - Data: `/mnt/apps/apps/portainer -> /data`

22. **nextcloud**
    - Config: `/mnt/apps/apps/nextcloud/config -> /config`
    - Data: `/mnt/apps/apps/nextcloud/data -> /data`

23. **nc-mariadb**
    - Data: `/mnt/apps/apps/mariadb -> /var/lib/mysql`

24. **nc-redis**
    - Data: `/mnt/apps/apps/nextcloud/redis -> /data`

25. **ix-karakeep-web-1**
    - Data: `/mnt/apps/apps/karakeep/data -> /data`

26. **ix-karakeep-meilisearch-1**
    - Data: `/mnt/apps/apps/karakeep/meilisearch -> /meili_data`

27. **redis**
    - Data: `/mnt/apps/apps/searxng/valkey-data2 -> /data`

28. **dns-server**
    - Config: `/mnt/apps/apps/technitium/config -> /etc/dns`

29. **ntfy**
    - Lib: `/mnt/apps/apps/ntfy/lib -> /var/lib/ntfy`
    - Config: `/mnt/apps/apps/ntfy/etc -> /etc/ntfy`
    - Cache: `/mnt/apps/apps/ntfy/cache -> /var/cache/ntfy`

### Gaming & Utility Apps (7 apps)
30. **ix-crafty-4-crafty-4-1**
    - Backups: `/mnt/apps/apps/crafty-4/backups -> /crafty/backups`
    - Import: `/mnt/apps/apps/crafty-4/import -> /crafty/import`
    - Logs: `/mnt/apps/apps/crafty-4/logs -> /crafty/logs`
    - Data: `/mnt/apps/apps/crafty-4/data -> /crafty/servers`
    - Config: `/mnt/apps/apps/crafty-4/config -> /crafty/app/config`

31. **ix-atuin-atuin-1**
    - Config: `/mnt/apps/apps/atuin/config -> /config`

32. **ix-atuin-atuin-db-1**
    - Database: `/mnt/apps/apps/atuin/database -> /var/lib/postgresql/data`

33. **planka**
    - Config: `/mnt/apps/apps/planka/config -> /config`

34. **apprise-api**
    - Attachments: `/mnt/apps/apps/apprise-api/attachments -> /attachments`
    - Config: `/mnt/apps/apps/apprise-api/config -> /config`

35. **faster-whisper**
    - Config: `/mnt/apps/apps/faster-whisper/config -> /config`

36. **media-streamy-vectorchord**
    - Data: `/mnt/apps/apps/streamystats/vectorchord_data -> /var/lib/postgresql/data`

---

## Section 2: Apps Still Using /mnt/.ix-apps/ Paths (19 apps)

### PRIORITY: Apps That Need Immediate Migration

#### Servarr Ecosystem Apps (6 apps)
1. **core-SuggestArr** - ⚠️ HIGH PRIORITY
   - `/mnt/.ix-apps/app_mounts/suggestarr/config -> /app/config/config_files`
   - Part of servarr stack

2. **core-audiobookrequest** - ⚠️ HIGH PRIORITY
   - `/mnt/.ix-apps/app_mounts/audiobookrequest/config -> /config`
   - Storage: `/mnt/storage/storage -> /storage`
   - Part of servarr stack

3. **core-huntarr** - ⚠️ HIGH PRIORITY
   - `/mnt/.ix-apps/app_mounts/huntarr/config -> /config`
   - Storage: `/mnt/storage/storage -> /storage`
   - Part of servarr stack

4. **core-decluttarr** - ⚠️ HIGH PRIORITY
   - `/mnt/.ix-apps/app_mounts/decluttarr/config.yaml -> /app/config/config.yaml`
   - Storage: `/mnt/storage/storage -> /storage`
   - Part of servarr stack

5. **core-homarr** - ⚠️ HIGH PRIORITY
   - `/mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered/homarr/appdata -> /appdata`
   - Dashboard for servarr stack
   - **RED FLAG:** Using app_configs path (unusual)

6. **core-whisparr** - ⚠️ HIGH PRIORITY
   - `/mnt/.ix-apps/app_mounts/whisparr/config -> /config`
   - `/mnt/.ix-apps/app_mounts/whisparr/data -> /data`
   - Storage: `/mnt/storage/storage -> /storage`
   - Part of servarr stack

#### Download Clients (3 apps)
7. **dmz-ytdl-sub** - ⚠️ MEDIUM PRIORITY
   - `/mnt/.ix-apps/app_mounts/ytdl-sub/config -> /config`
   - Storage: `/mnt/storage/storage -> /storage`

8. **dmz-nzbget** - ⚠️ MEDIUM PRIORITY
   - `/mnt/.ix-apps/app_mounts/nzbget/data -> /config`
   - Storage: `/mnt/storage/storage -> /storage`

9. **dmz-spottarr** - ⚠️ MEDIUM PRIORITY
   - `/mnt/.ix-apps/app_mounts/spottarr/data -> /data`
   - Storage: `/mnt/storage/storage -> /storage`

#### Network & VPN (1 app)
10. **dmz-gluetun** - ⚠️ MEDIUM PRIORITY
    - `/mnt/.ix-apps/app_mounts/gluetun -> /gluetun`
    - VPN container for DMZ apps

#### Content & Reading (2 apps)
11. **ix-calibre-calibre-1** - ⚠️ LOW PRIORITY
    - `/mnt/.ix-apps/app_mounts/calibre/config -> /config`
    - Storage: `/mnt/storage/storage -> /storage`

12. **ix-calibre-web-calibre-web-1** - ⚠️ LOW PRIORITY
    - `/mnt/.ix-apps/app_mounts/calibre-web/config -> /config`
    - Storage: `/mnt/storage/storage/Media.Books -> /books`

#### Media Processing (1 app)
13. **ix-tdarr-tdarr-1** - ⚠️ MEDIUM PRIORITY
    - `/mnt/.ix-apps/app_mounts/tdarr/configs -> /app/configs`
    - `/mnt/.ix-apps/app_mounts/tdarr/logs -> /app/logs`
    - `/mnt/.ix-apps/app_mounts/tdarr/server -> /app/server`
    - `/mnt/.ix-apps/app_mounts/tdarr/transcodes -> /temp`
    - Storage: `/mnt/storage/storage -> /storage`

#### Sync & Backup (1 app)
14. **ix-syncthing-syncthing-1** - ⚠️ LOW PRIORITY
    - `/mnt/.ix-apps/app_mounts/syncthing/config -> /var/syncthing`
    - Storage: `/mnt/storage/storage -> /var/syncthing/storage`

#### Workflow Automation (3 apps)
15. **ix-n8n-n8n-1** - ⚠️ LOW PRIORITY
    - `/mnt/.ix-apps/docker/volumes/ix-n8n_tmp-n8n-npm-cache/_data -> /.cache`
    - `/mnt/.ix-apps/app_mounts/n8n/data -> /data`
    - `/mnt/.ix-apps/docker/volumes/68cfc2334467cfdf6117bc1e33a1c5c643b12accb7ee313ee6a1763e110ba555/_data -> /tmp`

16. **ix-n8n-postgres-1** - ⚠️ LOW PRIORITY
    - `/mnt/.ix-apps/app_mounts/n8n/postgres_data -> /var/lib/postgresql`
    - `/mnt/.ix-apps/docker/volumes/1a63f43a56f8f4c498323973dda6a8d8ef7f9cd21d182fe7ba9b57636a610ee4/_data -> /var/lib/postgresql/data`

17. **ix-n8n-redis-1** - ⚠️ LOW PRIORITY
    - `/mnt/.ix-apps/docker/volumes/ix-n8n_redis-data/_data -> /data`

#### Password Management (2 apps)
18. **ix-vaultwarden-vaultwarden-1** - ⚠️ LOW PRIORITY
    - `/mnt/.ix-apps/app_mounts/vaultwarden/data -> /data`

19. **ix-vaultwarden-postgres-1** - ⚠️ LOW PRIORITY
    - `/mnt/.ix-apps/app_mounts/vaultwarden/postgres_data -> /var/lib/postgresql`
    - `/mnt/.ix-apps/docker/volumes/a6e5f8d4924c911aa04ac67df8afd9f5350d16aca87bcf4f8928d42ae199235f/_data -> /var/lib/postgresql/data`

---

## Section 3: Apps with Mixed Paths (2 apps)

### Partially Migrated Apps
1. **media-komga** - ✅ Mostly migrated, needs /tmp cleanup
   - Apps paths:
     - `/mnt/apps/apps/komga/config -> /config`
     - `/mnt/apps/apps/komga/data -> /data`
   - IX-Apps paths:
     - `/mnt/.ix-apps/docker/volumes/7c2c28d9a9c3e283a8d337d8c2a9a399ef75f3da9dfc93ef0712a4dfa97eeb80/_data -> /tmp`
   - Storage: `/mnt/storage/storage -> /storage`
   - **Status:** Config and data are correct, only temp volume needs cleanup

2. **searxng** - ✅ Mostly migrated, needs cache cleanup
   - Apps paths:
     - `/mnt/apps/apps/searxng/config -> /etc/searxng`
   - IX-Apps paths:
     - `/mnt/.ix-apps/docker/volumes/a1920fc9105aea6599f6b2efa615791b5c50c40d94f27aa2c1e973d64ecedc45/_data -> /var/cache/searxng`
   - **Status:** Config is correct, only cache volume needs cleanup

---

## Section 4: Apps with No Relevant Mounts (8 apps)

These apps don't use persistent storage or use other mount strategies:
1. **media-streamy-nextjs-app** - Stateless app
2. **media-streamy-job-server** - Stateless app
3. **dmz-flaresolverr** - Stateless proxy
4. **media-prefetcharr** - Stateless automation
5. **dmz-deunhealth** - Stateless health checker
6. **media-browser** - Stateless web app
7. **ix-karakeep-chrome-1** - Stateless browser
8. **ix-watchtower-watchtower-1** - Container updater

---

## Section 5: Migration Priority Recommendations

### Phase 27 - HIGH PRIORITY (Servarr Ecosystem)
**Timeline:** Immediate
**Apps (6):**
- core-SuggestArr
- core-audiobookrequest
- core-huntarr
- core-decluttarr
- core-homarr (special case - uses app_configs path)
- core-whisparr

**Rationale:** These are all part of the servarr ecosystem and should have been migrated in Phase 26. They're directly related to media management workflow.

### Phase 28 - MEDIUM PRIORITY (Download & DMZ Apps)
**Timeline:** Within 1 week
**Apps (4):**
- dmz-ytdl-sub
- dmz-nzbget
- dmz-spottarr
- dmz-gluetun (VPN container)

**Rationale:** These apps support the download infrastructure and should be migrated for consistency with qbittorrent and sabnzbd.

### Phase 29 - MEDIUM PRIORITY (Media Processing)
**Timeline:** Within 2 weeks
**Apps (1):**
- ix-tdarr-tdarr-1

**Rationale:** Media transcoding app with multiple mount points. Should be migrated for consistency.

### Phase 30 - LOW PRIORITY (Infrastructure Apps)
**Timeline:** Within 1 month
**Apps (8):**
- ix-calibre-calibre-1
- ix-calibre-web-calibre-web-1
- ix-syncthing-syncthing-1
- ix-n8n-n8n-1 (+ postgres + redis)
- ix-vaultwarden-vaultwarden-1 (+ postgres)

**Rationale:** These apps work fine with current paths. Migrate when convenient for consistency.

### Mixed Path Cleanup - OPTIONAL
**Timeline:** When convenient
**Apps (2):**
- media-komga (cleanup /tmp mount)
- searxng (cleanup cache mount)

**Rationale:** These apps are already mostly migrated. The ix-apps mounts are only for temporary/cache data.

---

## Section 6: Verification Against Phase 26 Objectives

### Phase 26 Target Apps - All Verified ✅

| App | Status | Config Path | Storage Path |
|-----|--------|-------------|--------------|
| qbittorrent | ✅ CORRECT | `/mnt/apps/apps/qbittorrent/config` | `/mnt/storage/storage` |
| sabnzbd | ✅ CORRECT | `/mnt/apps/apps/sabnzbd/config` | `/mnt/storage/storage` |
| prowlarr | ✅ CORRECT | `/mnt/apps/apps/prowlarr/config` | - |
| sonarr | ✅ CORRECT | `/mnt/apps/apps/sonarr/config` | `/mnt/storage/storage` |
| radarr | ✅ CORRECT | `/mnt/apps/apps/radarr/config` | `/mnt/storage/storage` |
| bazarr | ✅ CORRECT | `/mnt/apps/apps/bazarr/config` | `/mnt/storage/storage` |
| jellyseerr | ✅ CORRECT | `/mnt/apps/apps/jellyseerr/config` | - |
| jellyfin | ✅ CORRECT | `/mnt/apps/apps/jellyfin/config` | `/mnt/storage/storage` |
| janitorr | ✅ CORRECT | `/mnt/apps/apps/janitorr/config` | `/mnt/storage/storage` |

**Result:** All 9 Phase 26 apps are correctly using `/mnt/apps/apps/` paths with NO ix-apps remnants.

---

## Section 7: Red Flags & Issues Found

### Critical Issues
1. **core-homarr** uses unusual path:
   - `/mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered/homarr/appdata`
   - This is in app_configs (template directory) instead of app_mounts
   - **Action Required:** Special migration needed

### Warnings
1. **19 apps still on ix-apps** - More than expected (29% of total)
2. **Servarr ecosystem incomplete** - 6 servarr-related apps missed in Phase 26
3. **DMZ infrastructure** - Several DMZ apps not migrated with their peers

### Good News
1. **No compose/runtime discrepancies** - What's configured matches what's running
2. **Phase 26 100% successful** - All targeted apps properly migrated
3. **Mixed paths are minor** - Only temp/cache volumes, not critical data

---

## Section 8: Recommended Next Actions

### Immediate (This Week)
1. **Plan Phase 27** - Migrate the 6 remaining servarr apps
2. **Investigate core-homarr** - Determine why it's using app_configs path
3. **Review servarr-* compose files** - Understand why some apps were missed

### Short Term (Next 2 Weeks)
1. **Execute Phase 27** - Migrate servarr ecosystem apps
2. **Execute Phase 28** - Migrate DMZ download infrastructure
3. **Execute Phase 29** - Migrate tdarr

### Medium Term (Next Month)
1. **Execute Phase 30** - Migrate remaining infrastructure apps
2. **Cleanup mixed paths** - Remove temporary ix-apps mounts from komga and searxng
3. **Final audit** - Verify 100% migration completion

### Long Term (Future)
1. **Documentation** - Update all app documentation with new paths
2. **Backup verification** - Ensure backup scripts use new paths
3. **Monitoring** - Set up alerts for any new ix-apps path usage

---

## Section 9: Audit Methodology

### Data Collection
1. Found all docker-compose files in `/mnt/.ix-apps/app_configs/*/versions/*/templates/rendered/`
2. Identified active compose files (latest version per app)
3. Inspected all 65 running containers for actual mount points
4. Compared configured vs runtime mounts

### Analysis Approach
1. Categorized mounts by path type (apps, ix-apps, storage, other)
2. Identified apps using correct paths vs legacy paths
3. Found mixed-path apps (partially migrated)
4. Verified Phase 26 migration success
5. Prioritized remaining migrations

### Verification
- No permission errors during runtime inspection
- All running containers successfully queried
- Cross-referenced container names with compose file apps
- Validated Phase 26 apps individually

---

## Appendix A: Complete Container List by Category

### Apps Using /mnt/apps/apps/ (36 total)
apprise-api, changedetection, core-bazarr, core-checkrr, core-kapowarr, core-radarr, core-sonarr, dmz-pinchflat, dmz-prowlarr, dmz-qbittorrent, dmz-sabnzbd, dns-server, ersatztv, faster-whisper, freshrss, ix-atuin-atuin-1, ix-atuin-atuin-db-1, ix-crafty-4-crafty-4-1, ix-karakeep-meilisearch-1, ix-karakeep-web-1, ix-portainer-portainer-1, jackett, media-audiobookshelf, media-janitorr, media-jelly-meilisearch, media-jellyfin, media-jellyseerr, media-stash, media-streamy-vectorchord, nc-mariadb, nc-redis, nextcloud, ntfy, planka, readeck, redis

### Apps Using /mnt/.ix-apps/ Only (19 total)
core-SuggestArr, core-audiobookrequest, core-decluttarr, core-homarr, core-huntarr, core-whisparr, dmz-gluetun, dmz-nzbget, dmz-spottarr, dmz-ytdl-sub, ix-calibre-calibre-1, ix-calibre-web-calibre-web-1, ix-n8n-n8n-1, ix-n8n-postgres-1, ix-n8n-redis-1, ix-syncthing-syncthing-1, ix-tdarr-tdarr-1, ix-vaultwarden-postgres-1, ix-vaultwarden-vaultwarden-1

### Apps with Mixed Paths (2 total)
media-komga, searxng

### Apps with No Relevant Mounts (8 total)
dmz-deunhealth, dmz-flaresolverr, ix-karakeep-chrome-1, ix-watchtower-watchtower-1, media-browser, media-prefetcharr, media-streamy-job-server, media-streamy-nextjs-app

---

## Appendix B: Phase 26 Detailed Verification

### Phase 26 Apps - Full Mount Details

**dmz-qbittorrent:**
```
/mnt/apps/apps/qbittorrent/config -> /config
/mnt/storage/storage -> /storage
```
Status: ✅ Perfect

**dmz-sabnzbd:**
```
/mnt/apps/apps/sabnzbd/config -> /config
/mnt/storage/storage -> /storage
```
Status: ✅ Perfect

**dmz-prowlarr:**
```
/mnt/apps/apps/prowlarr/config -> /config
```
Status: ✅ Perfect

**core-sonarr:**
```
/mnt/apps/apps/sonarr/config -> /config
/mnt/storage/storage -> /storage
```
Status: ✅ Perfect

**core-radarr:**
```
/mnt/apps/apps/radarr/config -> /config
/mnt/storage/storage -> /storage
```
Status: ✅ Perfect

**core-bazarr:**
```
/mnt/apps/apps/bazarr/config -> /config
/mnt/storage/storage -> /storage
/mnt/storage/storage/Movies -> /movies
/mnt/storage/storage/Shows -> /tv
```
Status: ✅ Perfect

**media-jellyseerr:**
```
/mnt/apps/apps/jellyseerr/config -> /app/config
```
Status: ✅ Perfect

**media-jellyfin:**
```
/mnt/apps/apps/jellyfin/config -> /config
/mnt/storage/storage -> /storage
```
Status: ✅ Perfect

**media-janitorr:**
```
/mnt/apps/apps/janitorr/config/application.yml -> /workspace/application.yml
/mnt/apps/apps/janitorr/logs -> /logs
/mnt/storage/storage -> /storage
```
Status: ✅ Perfect

---

**End of Report**

Generated by comprehensive container inspection on waterbug.lan
All mount points verified against running containers
No discrepancies found between configuration and runtime
