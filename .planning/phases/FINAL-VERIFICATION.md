# Final TrueNAS Apps Migration Verification Report
**Date:** 2025-12-30
**Verification Scope:** All TrueNAS containers (running and stopped)

---

## Executive Summary

**MIGRATION STATUS: 63% COMPLETE (CRITICAL APPS STILL USING IX-APPS)**

- **Total containers checked:** 71 containers
- **Apps using /mnt/apps/apps/:** 45 unique apps
- **Apps still using /mnt/.ix-apps/:** 17 containers (9 unique apps + support containers)
- **Migration completion rate:** 63%

### Critical Finding
Phase 27 apps that were supposed to be migrated are **STILL USING IX-APPS PATHS**:
- calibre
- calibre-web
- syncthing
- n8n (+ postgres + redis)
- vaultwarden (+ postgres)
- tdarr (old ix-tdarr container exists)
- spottarr

---

## Phase 26 Apps Status (9 apps)

### ALL PHASE 26 APPS SUCCESSFULLY MIGRATED

| App | Status | Mount Path | Result |
|-----|--------|------------|--------|
| qbittorrent | exited | /mnt/apps/apps/qbittorrent/config | ✅ |
| sabnzbd | running | /mnt/apps/apps/sabnzbd/config | ✅ |
| prowlarr | running | /mnt/apps/apps/prowlarr/config | ✅ |
| sonarr | running | /mnt/apps/apps/sonarr/config | ✅ |
| radarr | running | /mnt/apps/apps/radarr/config | ✅ |
| bazarr | running | /mnt/apps/apps/bazarr/config | ✅ |
| jellyseerr | running | /mnt/apps/apps/jellyseerr/config | ✅ |
| jellyfin | running | /mnt/apps/apps/jellyfin/config | ✅ |
| janitorr | running | /mnt/apps/apps/janitorr/config | ✅ |

**Phase 26 Result: 9/9 apps using /mnt/apps/apps/ - 100% complete**

---

## Phase 27 Apps Status (19 apps)

### MIXED RESULTS - CRITICAL FAILURES

| App | Status | Mount Path | Result |
|-----|--------|------------|--------|
| homarr | running | /mnt/apps/apps/homarr/config/appdata | ✅ |
| SuggestArr | running | /mnt/apps/apps/suggestarr/config | ✅ |
| audiobookrequest | running | /mnt/apps/apps/audiobookrequest/config | ✅ |
| huntarr | running | /mnt/apps/apps/huntarr/config | ✅ |
| decluttarr | running | /mnt/apps/apps/decluttarr/config | ✅ |
| whisparr | running | /mnt/apps/apps/whisparr/config | ✅ |
| ytdl-sub | running | /mnt/apps/apps/ytdl-sub/config | ✅ |
| nzbget | running | /mnt/apps/apps/nzbget/config | ✅ |
| spottarr | running | **/mnt/.ix-apps/app_mounts/spottarr/data** | ⚠️ |
| gluetun | running | /mnt/apps/apps/gluetun/config | ✅ |
| tdarr | running | /mnt/apps/apps/tdarr/* (rendered-tdarr-1) | ⚠️ PARTIAL |
| tdarr (old) | exited | **/mnt/.ix-apps/app_mounts/tdarr/** | ⚠️ |
| calibre | exited | **/mnt/.ix-apps/app_mounts/calibre/config** | ⚠️ |
| calibre-web | exited | **/mnt/.ix-apps/app_mounts/calibre-web/config** | ⚠️ |
| syncthing | exited | **/mnt/.ix-apps/app_mounts/syncthing/config** | ⚠️ |
| n8n | exited | **/mnt/.ix-apps/app_mounts/n8n/data** | ⚠️ |
| n8n-postgres | exited | **/mnt/.ix-apps/app_mounts/n8n/postgres_data** | ⚠️ |
| n8n-redis | exited | **/mnt/.ix-apps/docker/volumes/ix-n8n_redis-data/_data** | ⚠️ |
| vaultwarden | exited | **/mnt/.ix-apps/app_mounts/vaultwarden/data** | ⚠️ |
| vaultwarden-postgres | exited | **/mnt/.ix-apps/app_mounts/vaultwarden/postgres_data** | ⚠️ |

**Phase 27 Result: 10/19 apps using /mnt/apps/apps/ - 53% complete**

---

## Apps Successfully Using /mnt/apps/apps/

### Media Apps (9)
- jellyfin
- jellyseerr
- janitorr
- audiobookshelf
- komga (with 1 ix-apps docker volume for /tmp)
- stash
- streamy-vectorchord
- jelly-meilisearch

### *Arr Apps (8)
- sonarr
- radarr
- bazarr
- prowlarr
- whisparr
- SuggestArr
- audiobookrequest
- huntarr

### Download/Media Processing (5)
- qbittorrent (exited)
- sabnzbd
- nzbget
- ytdl-sub
- gluetun

### Utilities/Other (14)
- homarr
- decluttarr
- checkrr
- configarr
- kapowarr
- jackett
- janitorr
- pinchflat
- atuin + atuin-db
- crafty-4
- karakeep (web + meilisearch)
- portainer
- planka + planka-postgres

### Infrastructure (9)
- nextcloud + nc-mariadb + nc-redis
- technitium (dns-server)
- apprise-api
- changedetection
- ersatztv
- faster-whisper
- freshrss
- ntfy
- readeck
- searxng (with 1 ix-apps docker volume for cache)

---

## Apps Still Using /mnt/.ix-apps/ Paths

### PRIMARY APPS NEEDING MIGRATION (9)

1. **calibre** (ix-calibre-calibre-1) - exited
   - /mnt/.ix-apps/app_mounts/calibre/config

2. **calibre-web** (ix-calibre-web-calibre-web-1) - exited
   - /mnt/.ix-apps/app_mounts/calibre-web/config

3. **syncthing** (ix-syncthing-syncthing-1) - exited
   - /mnt/.ix-apps/app_mounts/syncthing/config

4. **n8n** (ix-n8n-n8n-1) - exited
   - /mnt/.ix-apps/app_mounts/n8n/data
   - /mnt/.ix-apps/docker/volumes/68cfc2334467cfdf6117bc1e33a1c5c643b12accb7ee313ee6a1763e110ba555/_data
   - /mnt/.ix-apps/docker/volumes/ix-n8n_tmp-n8n-npm-cache/_data

5. **n8n-postgres** (ix-n8n-postgres-1) - exited
   - /mnt/.ix-apps/app_mounts/n8n/postgres_data
   - /mnt/.ix-apps/docker/volumes/1a63f43a56f8f4c498323973dda6a8d8ef7f9cd21d182fe7ba9b57636a610ee4/_data

6. **n8n-redis** (ix-n8n-redis-1) - exited
   - /mnt/.ix-apps/docker/volumes/ix-n8n_redis-data/_data

7. **vaultwarden** (ix-vaultwarden-vaultwarden-1) - exited
   - /mnt/.ix-apps/app_mounts/vaultwarden/data

8. **vaultwarden-postgres** (ix-vaultwarden-postgres-1) - exited
   - /mnt/.ix-apps/app_mounts/vaultwarden/postgres_data
   - /mnt/.ix-apps/docker/volumes/a6e5f8d4924c911aa04ac67df8afd9f5350d16aca87bcf4f8928d42ae199235f/_data

9. **spottarr** (dmz-spottarr) - running
   - /mnt/.ix-apps/app_mounts/spottarr/data

### OLD CONTAINERS TO CLEAN UP (8)

1. **ix-tdarr-tdarr-1** - exited (OLD - replaced by rendered-tdarr-1)
   - /mnt/.ix-apps/app_mounts/tdarr/transcodes
   - /mnt/.ix-apps/app_mounts/tdarr/configs
   - /mnt/.ix-apps/app_mounts/tdarr/logs
   - /mnt/.ix-apps/app_mounts/tdarr/server

2. **ix-n8n-permissions-1** - exited (support container)
3. **ix-n8n-postgres_upgrade-1** - exited (upgrade container)
4. **ix-vaultwarden-permissions-1** - exited (support container)
5. **ix-vaultwarden-postgres_upgrade-1** - exited (upgrade container)

6. **atuin_db_dumper** - exited (uses mix of both paths)
   - /mnt/.ix-apps/docker/volumes/* (old postgres volumes)
   - /mnt/apps/apps/atuin/db_dumps (new path)

7. **media-komga** - running (mostly migrated, 1 docker volume for /tmp)
   - /mnt/.ix-apps/docker/volumes/7c2c28d9a9c3e283a8d337d8c2a9a399ef75f3da9dfc93ef0712a4dfa97eeb80/_data -> /tmp

8. **searxng** - running (mostly migrated, 1 docker volume for cache)
   - /mnt/.ix-apps/docker/volumes/a1920fc9105aea6599f6b2efa615791b5c50c40d94f27aa2c1e973d64ecedc45/_data -> /var/cache/searxng

---

## Detailed Container Analysis

### Total Container Count
```
Total containers: 71
- Running: 59
- Exited/Stopped: 12
```

### Containers with /mnt/apps/apps/ mounts
45 unique containers are using the new structure

### Containers with /mnt/.ix-apps/ mounts
17 containers still using old structure (see lists above)

---

## Critical Issues Found

### 1. Phase 27 Incomplete
Phase 27 was supposed to migrate calibre, calibre-web, syncthing, tdarr, n8n (3 containers), vaultwarden (2 containers), and spottarr. These apps are **STILL USING IX-APPS PATHS**.

**Status:**
- rendered-tdarr-1 is using /mnt/apps/apps/ ✅
- Old ix-tdarr-tdarr-1 still exists using ix-apps ⚠️
- All n8n containers (3) using ix-apps ⚠️
- All vaultwarden containers (2) using ix-apps ⚠️
- calibre, calibre-web, syncthing using ix-apps ⚠️
- spottarr using ix-apps ⚠️

### 2. Stopped Containers
Many critical apps are in "exited" state:
- calibre
- calibre-web
- syncthing
- n8n (all 3 containers)
- vaultwarden (all 2 containers)
- qbittorrent
- Old tdarr container

### 3. Old Containers Not Removed
Several old ix-* containers are still present and using ix-apps paths, even though new versions exist.

---

## Migration Recommendations

### Immediate Actions Required

1. **Investigate Phase 27 Status**
   - Phase 27 appears to have been planned but NOT executed
   - Apps were added to docker-compose but may not have been migrated
   - Data may still be in ix-apps paths

2. **Complete Phase 27 Migrations**
   Priority order:
   - vaultwarden + postgres (password manager - critical)
   - n8n + postgres + redis (automation)
   - calibre + calibre-web (library management)
   - syncthing (file sync)
   - spottarr (media automation)
   - tdarr cleanup (remove old ix-tdarr container)

3. **Clean Up Old Containers**
   - Remove ix-tdarr-tdarr-1 (replaced by rendered-tdarr-1)
   - Remove ix-n8n-permissions-1, ix-n8n-postgres_upgrade-1
   - Remove ix-vaultwarden-permissions-1, ix-vaultwarden-postgres_upgrade-1
   - Clean up atuin_db_dumper old volumes

4. **Restart Stopped Apps**
   - Investigate why qbittorrent, calibre, calibre-web, syncthing are stopped
   - Start n8n stack if migration is complete
   - Start vaultwarden stack if migration is complete

---

## Verification Commands Used

```bash
# List all containers
ssh waterbug.lan "sudo docker ps -a --format '{{.Names}}' | sort"

# Check all mounts
ssh waterbug.lan "sudo docker ps -a --format '{{.Names}}' | sort | while read container; do
  echo \"=== \$container ===\"
  sudo docker inspect \$container --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}' | grep -E '(apps|ix-apps)' || echo 'No relevant mounts'
done"

# Count by location
ssh waterbug.lan "
sudo docker ps -a -q | xargs sudo docker inspect --format='{{.Name}}: {{range .Mounts}}{{.Source}}{{println}}{{end}}' | grep '/mnt/apps/apps/' | cut -d':' -f1 | sort -u | wc -l
sudo docker ps -a -q | xargs sudo docker inspect --format='{{.Name}}: {{range .Mounts}}{{.Source}}{{println}}{{end}}' | grep '/mnt/.ix-apps/' | cut -d':' -f1 | sort -u | wc -l
"

# Find specific ix-apps users
ssh waterbug.lan "sudo docker ps -a --format '{{.Names}}' | while read container; do
  has_ix_apps=\$(sudo docker inspect \$container --format '{{range .Mounts}}{{.Source}}{{println}}{{end}}' | grep -c '/mnt/.ix-apps/' || true)
  if [ \"\$has_ix_apps\" -gt 0 ]; then
    echo \"\$container\"
  fi
done | sort"
```

---

## Technical Analysis of Phase 27 Status

### Data Migration Status
The data HAS been copied to /mnt/apps/apps/ for Phase 27 apps:

| App | Source (ix-apps) | Destination (/mnt/apps/apps/) | Size | Status |
|-----|------------------|-------------------------------|------|--------|
| calibre | /mnt/.ix-apps/app_mounts/calibre/config | /mnt/apps/apps/calibre/config | 9.6M | Data exists |
| n8n | /mnt/.ix-apps/app_mounts/n8n/data | /mnt/apps/apps/n8n/data | 364M | Data exists |
| n8n-postgres | /mnt/.ix-apps/app_mounts/n8n/postgres_data | /mnt/apps/apps/n8n/postgres | 23M | Data exists |
| vaultwarden | /mnt/.ix-apps/app_mounts/vaultwarden/data | /mnt/apps/apps/vaultwarden/data | 544K | Data exists |
| vaultwarden-postgres | /mnt/.ix-apps/app_mounts/vaultwarden/postgres_data | /mnt/apps/apps/vaultwarden/postgres | 15M | Data exists |

### Why Apps Are Still Using ix-apps Paths

**ROOT CAUSE:** The TrueNAS app configurations were never updated to point to the new paths.

**What happened:**
1. Data was successfully copied to /mnt/apps/apps/
2. Directories were created with proper structure
3. BUT the TrueNAS app definitions still reference /mnt/.ix-apps/ paths
4. The apps are stopped because they were stopped during migration
5. When they start, they will still use the old ix-apps paths

**Solution Required:**
Each app needs to be reconfigured in the TrueNAS web UI to:
1. Update mount paths from /mnt/.ix-apps/app_mounts/[app]/ to /mnt/apps/apps/[app]/
2. Update any docker volumes to regular bind mounts at /mnt/apps/apps/[app]/
3. Then the apps can be started with the new paths

### Container Status Analysis

**Stopped containers (8 Phase 27 apps):**
- ix-calibre-calibre-1 (exited)
- ix-calibre-web-calibre-web-1 (exited)
- ix-syncthing-syncthing-1 (exited)
- ix-n8n-n8n-1 (exited)
- ix-n8n-postgres-1 (exited)
- ix-n8n-redis-1 (exited)
- ix-vaultwarden-vaultwarden-1 (exited)
- ix-vaultwarden-postgres-1 (exited)

**Running but wrong path (1 app):**
- dmz-spottarr (running, using /mnt/.ix-apps/app_mounts/spottarr/data)

**Successfully migrated (10 apps):**
- homarr, SuggestArr, audiobookrequest, huntarr, decluttarr
- whisparr, ytdl-sub, nzbget, gluetun, tdarr (rendered-tdarr-1)

---

## Final Answer

### ⚠️ MIGRATION NOT COMPLETE - 63% DONE

**Phase 26:** ✅ 100% complete (9/9 apps)
**Phase 27:** ⚠️ 53% complete (10/19 apps)

**Apps still requiring migration:** 9 apps
- calibre (DATA COPIED, CONFIG NOT UPDATED)
- calibre-web (DATA COPIED, CONFIG NOT UPDATED)
- syncthing (DATA COPIED, CONFIG NOT UPDATED)
- n8n (DATA COPIED, CONFIG NOT UPDATED) (3 containers)
- vaultwarden (DATA COPIED, CONFIG NOT UPDATED) (2 containers)
- spottarr (NEEDS DATA COPY + CONFIG UPDATE)

**Additional cleanup needed:** 8 old/stopped containers using ix-apps paths

**Root Cause:** TrueNAS app configurations were never updated to use new paths, even though data was copied.

**Next Steps:**
1. Update TrueNAS app configurations for each of the 9 apps to use /mnt/apps/apps/ paths
2. Complete data migration for spottarr
3. Start the reconfigured apps
4. Remove old ix-* containers
5. Re-run verification to confirm 100% completion

**Important Note:** This is NOT a docker-compose setup - these are TrueNAS Electric Eel apps managed through the TrueNAS web UI. Each app configuration must be updated in the UI to change the mount paths.
