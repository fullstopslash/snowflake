# App Functional Status

**Date:** 2025-12-30
**System:** waterbug.lan

## Apps Already Migrated - Verified Working

### Jellyfin
- **Status:** ✓ WORKING - Using /mnt/apps/apps/jellyfin/config/
- **Size:** 27G in /mnt/apps/apps/, only 2K remnant in ix-apps
- **Container:** media-jellyfin (running, Up About an hour)
- **Web UI:** http://localhost:8096 - Accessible (HTTP 302 redirect working)
- **Volumes:**
  - Config: `/mnt/apps/apps/jellyfin/config → /config`
  - Storage: `/mnt/storage/storage → /storage` (media library)
- **Action:** ✓ Migration complete, verify all features working
- **Cleanup:** Can remove /mnt/.ix-apps/app_mounts/jellyfin/ (2K) after verification

### Janitorr
- **Status:** ✓ WORKING - Using /mnt/apps/apps/janitorr/config/application.yml
- **Size:** 6K in /mnt/apps/apps/ (single config file mount)
- **Container:** media-janitorr (running, Up 10 hours, healthy)
- **Volumes:**
  - Config: `/mnt/apps/apps/janitorr/config/application.yml → /workspace/application.yml` (bind mount)
- **Action:** ✓ Migration complete, verify cleanup jobs working
- **Note:** Uses single file bind mount (not full directory)

## Apps in ix-apps - Currently Running (NEED MIGRATION)

### Wave 1: Simple Config

#### Recyclarr
- **Status:** Running but location unknown (not in docker ps output shown)
- **Size:** 119M in /mnt/.ix-apps/app_mounts/recyclarr/config/
- **Database:** None (config files only)
- **Priority:** LOW - Test migration app
- **Action Required:** Migrate config directory, update compose file

### Wave 2: Download Clients

#### qBittorrent
- **Status:** ✓ RUNNING - dmz-qbittorrent
- **Size:** 21M
- **Container:** Up 53 minutes (healthy)
- **Location:** /mnt/.ix-apps/app_mounts/qbittorrent/config/
- **Database:** Config files + torrent session data
- **Priority:** HIGH - Download infrastructure
- **Action Required:** Stop container, rsync config, update compose, restart, verify torrents

#### SABnzbd
- **Status:** ✓ RUNNING - dmz-sabnzbd
- **Size:** 3.2M
- **Container:** Up 10 hours
- **Location:** /mnt/.ix-apps/app_mounts/sabnzbd/config/
- **Database:** SQLite + config files
- **Priority:** HIGH - Download infrastructure
- **Action Required:** Stop container, rsync config+db, update compose, restart, verify queue

### Wave 3: Indexer Management

#### Prowlarr
- **Status:** ✓ RUNNING - dmz-prowlarr
- **Size:** 245M
- **Container:** Up 10 hours (lscr.io/linuxserver/prowlarr:develop)
- **Location:** /mnt/.ix-apps/app_mounts/prowlarr/config/
- **Database:** SQLite - prowlarr.db (317M), logs.db (2.4M)
- **Priority:** CRITICAL - Central indexer management
- **Dependencies:** All *arr apps depend on this
- **Action Required:** Stop container, rsync config+dbs (including .db-shm and .db-wal), update compose, restart, verify indexers + app syncs

### Wave 4: Content Automation

#### Sonarr
- **Status:** ✓ RUNNING - core-sonarr
- **Size:** 178M
- **Container:** Up 10 hours (healthy, lscr.io/linuxserver/sonarr:develop)
- **Location:** /mnt/.ix-apps/app_mounts/sonarr/config/
- **Database:** SQLite - sonarr.db (96M), logs.db (6M)
- **MediaCover:** 103 TV show posters
- **Priority:** HIGH - TV automation
- **Dependencies:** Prowlarr, qBittorrent/SABnzbd
- **Action Required:** Stop container, rsync config+dbs+MediaCover, update compose, restart, verify series+Prowlarr connection

#### Radarr
- **Status:** ✓ RUNNING - core-radarr
- **Size:** 443M (largest *arr app)
- **Container:** Up 10 hours (healthy, lscr.io/linuxserver/radarr:develop)
- **Location:** /mnt/.ix-apps/app_mounts/radarr/config/
- **Database:** SQLite - radarr.db (22M), logs.db (5M)
- **MediaCover:** 320 movie posters
- **Priority:** HIGH - Movie automation
- **Dependencies:** Prowlarr, qBittorrent/SABnzbd
- **Action Required:** Stop container, rsync config+dbs+MediaCover, update compose, restart, verify movies+custom formats+Prowlarr

#### Bazarr
- **Status:** ✓ RUNNING - core-bazarr
- **Size:** 4.2M
- **Container:** Up 10 hours (lscr.io/linuxserver/bazarr:latest)
- **Location:** /mnt/.ix-apps/app_mounts/bazarr/config/
- **Database:** SQLite
- **Priority:** MEDIUM - Subtitle automation
- **Dependencies:** Sonarr, Radarr
- **Action Required:** Stop container, rsync config+db, update compose, restart, verify Sonarr/Radarr connections

#### Lidarr
- **Status:** ✗ NOT RUNNING - No container found
- **Size:** 891K
- **Location:** /mnt/.ix-apps/app_mounts/lidarr/config/
- **Database:** SQLite (likely)
- **Priority:** LOW - Music automation (not in use)
- **Decision:** SKIP migration or archive data and delete

#### Readarr
- **Status:** ✗ NOT RUNNING - No containers found
- **Instances:**
  - readar: 997M
  - readar_ebooks: 740M
  - readar_audiobooks: 137M
- **Total Size:** 1.87G across 3 instances
- **Priority:** LOW - Book automation (not in use)
- **Decision:** SKIP migration unless determined to be needed

### Wave 5: User-Facing Services

#### Jellyseerr (Overseerr alternative)
- **Status:** ✓ RUNNING - media-jellyseerr
- **Size:** 2.0M
- **Container:** Up 10 hours (fallenbagel/jellyseerr:latest)
- **Location:** /mnt/.ix-apps/app_mounts/jellyseerr/config/
- **Database:** SQLite
- **Priority:** HIGH - User request management
- **Dependencies:** Sonarr, Radarr
- **Action Required:** Stop container, rsync config+db, update compose, restart, verify users+requests+Sonarr/Radarr connections

## Apps NOT Found / Not Migrating

### Tautulli
- **Status:** NOT FOUND - No container, no ix-apps directory
- **Action:** N/A - Not in use

### Notifiarr
- **Status:** NOT FOUND - No container, no ix-apps directory
- **Action:** N/A - Not in use

### Unpackerr
- **Status:** NOT FOUND - No container, no ix-apps directory
- **Action:** N/A - Not in use

### Configarr
- **Status:** Found in /mnt/apps/apps/configarr/ (19M, has git repo)
- **Container:** Unknown (need to check if running)
- **Action:** Verify if already migrated or not in use

## Docker Compose Detection

Based on volume mounts and container naming, apps appear to be managed via **docker-compose** (not TrueNAS SCALE apps). Need to:

1. **Find docker-compose file(s)** - Likely in /mnt/apps/ or /root/ or /opt/
2. **Update volume paths** - Change from `/mnt/.ix-apps/app_mounts/app/config` to `/mnt/apps/apps/app/config`
3. **Docker compose down/up** - Restart services with new paths

## Action Items for Verification Phase

- [ ] Locate docker-compose.yml file(s)
- [ ] Verify Jellyfin: Access UI, check libraries, test playback, verify users
- [ ] Verify Janitorr: Check config loaded, verify cleanup schedules, test *arr connections
- [ ] Test Configarr: Determine if running and if already migrated
- [ ] Confirm Lidarr/Readarr not needed (no containers, not in use)
- [ ] Document docker-compose structure for migration procedure

## Summary Statistics

| Status | Count | Total Size |
|--------|-------|------------|
| Already Migrated | 2 | 27G |
| Running - Need Migration | 7 | ~900M |
| Not Running - Skip | 3 | ~1.9G |
| **Total to Migrate** | **7 apps** | **~900M** |

## Revised Migration Scope

**Original Plan:** 16 apps across 6 waves
**Actual Scope:** 7-9 apps in 5 waves (Lidarr, Readarr instances skipped, no Tautulli/Notifiarr/Unpackerr)

**Data to Migrate:** ~900M (much smaller than planned ~2.7GB due to skipping unused apps)

**Estimated Migration Time:** 1.5-2 hours hands-on time across 5 waves
