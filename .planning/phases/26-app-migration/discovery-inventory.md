# /mnt/apps/apps/ Inventory

**Date:** 2025-12-30
**System:** waterbug.lan

## Summary

The /mnt/apps/apps/ directory contains 38 application directories, but **NONE of the target Servarr stack apps** are present here yet. The Servarr apps are still in ix-apps managed storage.

## Apps Present in /mnt/apps/apps/ (Non-Servarr)

| App Name | Size | Structure | Owner:Group | Notes |
|----------|------|-----------|-------------|-------|
| adguard | 15K | config/, workdir/ | rain:rain | Active |
| apprise-api | 4.5K | attachments/, config/ | root:root | Active |
| atuin | 184M | config/, database/, db_dumps/ | rain:rain | Has database |
| audiobookshelf | 50M | config/, metadata/ | rain:rain | Active |
| changedetection | 5.1M | data/ | rain:rain | Active |
| checkrr | 790K | config/ | rain:rain | Active |
| configarr | 19M | config/, custom/, dockerrepos/, .git/, .jj/ | rain:rain | Has git repo |
| crafty-4 | 169M | backups/, config/, data/, import/, logs/ | rain:rain | Minecraft server |
| ersatztv | 335M | config/ | rain:rain | Active |
| faster-whisper | 42M | config/ | rain:rain | Active |
| flood | 16K | config/, data/ | rain:rain | Minimal |
| freshrss | 65M | config/, data/, extensions/, postgres_data/ | rain:rain | Has PostgreSQL |
| freshrss-old | 48M | data/, extensions/, postgres_data/ | rain:rain | Old backup |
| jackett | 1.5M | config/ | rain:rain | Indexer |
| janitorr | 6.0K | config/, logs/ | rain:rain / root:root | **ALREADY MIGRATED** |
| jelly-meilisearch | 221M | backups/, data.ms/, dumps/ | root:root | Jellyfin search |
| jellyfin | 27G | config/ | rain:rain | **ALREADY MIGRATED** |
| kapowarr | 870K | kapowarr-db/ | rain:rain | Active |
| karakeep | 434M | data/, meilisearch/ | rain:rain | Active |
| komga | 33M | config/, data/ | rain:rain | Comic server |
| mariadb | 45M | mysql/, nxtDB/, etc. | netdata:docker | Database for Nextcloud |
| mylar3 | 436K | config/ | rain:rain | Comic automation |
| nextcloud | 590M | config/, data/, redis/ | rain:rain / netdata:root | Active install |
| nextcloudxx | 2.4G | config/, data/, html/, postgres_data/, redis/ | root:rain / netdata:root | Backup/test install |
| ntfy | 15K | cache/, etc/, lib/ | root:root | Notification service |
| pihole | 512 | Empty | rain:rain | Not configured |
| pinchflat | 570M | config/ | rain:rain | YouTube downloader |
| planka | 15K | config/, db-data/ | rain:rain / 70 | Kanban board |
| portainer | 2.4M | Various protected dirs | root:rain | Container management |
| readeck | 41K | data/ | rain:rain | Read later |
| searxng | 35K | config/, valkey-data2/ | 977:977 / netdata:root | Search engine |
| stashapp | 26G | blobs/, cache/, config/, data/, generated/, metadata/ | rain:rain | Media organizer |
| stashappnext | 76M | pip-install/ | root:root | Next version test |
| streamystats | 70M | vectorchord_data/, vectorchord_dataxx/ | netdata:rain / rain:rain | Stats service |
| task-md | 64K | config/ | rain:rain | Task manager |
| technitium | 139M | config/ | root:root | DNS server |
| vaultwarden | 1.5K | config/, postgres/ | rain:rain | Password manager |
| whisper-asr | 861M | cache/ | rain:rain | Speech recognition |

## Apps NOT in /mnt/apps/apps/ (Target Servarr Stack)

These apps are still in ix-apps and need migration:

- [ ] **sonarr** - TV show automation
- [ ] **radarr** - Movie automation
- [ ] **prowlarr** - Indexer management
- [ ] **bazarr** - Subtitle automation
- [ ] **lidarr** - Music automation (in ix-apps but not running)
- [ ] **readarr** (readar_ebooks/audiobooks) - Book automation
- [ ] **qbittorrent** - Torrent client
- [ ] **sabnzbd** - Usenet client
- [ ] **jellyseerr** - Request management (Overseerr alternative)
- [ ] **recyclarr** - Config sync utility

## Already Migrated Apps

These apps are already using /mnt/apps/apps/:

- [x] **jellyfin** - 27G in /mnt/apps/apps/jellyfin/config/
- [x] **janitorr** - 6K in /mnt/apps/apps/janitorr/ (config file mount)

## Structure Issues Found

1. **Mixed ownership**: Some apps owned by root:root instead of rain:rain (apprise-api, jelly-meilisearch, ntfy, technitium, stashappnext, nextcloudxx postgres)
2. **Permission denied on database dirs**: mariadb, nextcloudxx postgres, planka db-data, portainer dirs, stashapp cache, streamystats vectorchord
3. **Inconsistent structure**: Some apps have custom directory structures (configarr has .git, crafty-4 has import/, etc.)
4. **Multiple Nextcloud installs**: nextcloud (active) and nextcloudxx (backup/test)

## Total Storage in /mnt/apps/apps/

Approximately **60GB** total (largest consumers: jellyfin 27G, stashapp 26G, nextcloud/nextcloudxx 3G combined)

## Key Findings

1. **No Servarr apps in /mnt/apps/apps/** - All target apps still in ix-apps
2. **Jellyfin already migrated** - But only config directory (metadata likely elsewhere)
3. **Janitorr already migrated** - Using bind mount for single config file
4. **SQLite databases** - Servarr apps use SQLite (.db files), NOT PostgreSQL (simplifies migration)
5. **Docker Compose deployment** - Apps running via docker-compose, not TrueNAS SCALE native apps
