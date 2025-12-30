# ix-apps Managed Storage Inventory

**Date:** 2025-12-30
**Location:** /mnt/.ix-apps/app_mounts/
**System:** waterbug.lan

## Summary

Found 62 app directories in ix-apps storage. The target Servarr stack apps are all present here and need migration.

## Target Servarr Apps in ix-apps (NEED MIGRATION)

| App Name | Size | Database Type | Status | Priority |
|----------|------|---------------|--------|----------|
| **sonarr** | 178M | SQLite | Running (core-sonarr) | HIGH - Wave 4 |
| **radarr** | 443M | SQLite | Running (core-radarr) | HIGH - Wave 4 |
| **prowlarr** | 245M | SQLite | Running (dmz-prowlarr) | CRITICAL - Wave 3 |
| **bazarr** | 4.2M | SQLite | Running (core-bazarr) | MEDIUM - Wave 4 |
| **lidarr** | 891K | SQLite | Not running | MEDIUM - Wave 4 |
| **readar** | 997M | SQLite | Not running | MEDIUM - Wave 4 |
| **readar_ebooks** | 740M | SQLite | Not running | MEDIUM - Wave 4 |
| **readar_audiobooks** | 137M | SQLite | Not running | MEDIUM - Wave 4 |
| **qbittorrent** | 21M | Config files | Running (dmz-qbittorrent) | HIGH - Wave 2 |
| **sabnzbd** | 3.2M | SQLite | Running (dmz-sabnzbd) | HIGH - Wave 2 |
| **jellyseerr** | 2.0M | SQLite | Running (media-jellyseerr) | HIGH - Wave 5 |
| **recyclarr** | 119M | Config only | Running | MEDIUM - Wave 1 |

## Already Migrated (In ix-apps BUT Using /mnt/apps/apps/)

| App Name | ix-apps Size | Status | Action Needed |
|----------|--------------|--------|---------------|
| **jellyfin** | 2.0K | Running from /mnt/apps/apps/jellyfin/config | Verify complete, cleanup ix-apps |
| **janitorr** | - | Running from /mnt/apps/apps/janitorr/config | Verify complete |

## Other Apps in ix-apps (Not Target for This Phase)

| App Name | Size | Notes |
|----------|------|-------|
| audiobookrequest | 9.5K | Running |
| audiobookshelf | 46M | Running |
| autobrr | 79K | Torrent automation |
| calibre | 9.7M | Book management |
| calibre-web | 61K | Book server |
| changedetection | 351K | Site monitoring |
| crafty-4 | 512 bytes | Minecraft (migrated to /mnt/apps/apps/) |
| decluttarr | 9.5K | Media cleanup |
| ersatztv | 295M | Channel creation |
| faster-whisper | 42M | Speech recognition |
| flaresolverr | 1.0K | Cloudflare bypass |
| freshrss | 147K | RSS reader |
| gluetun | 677K | VPN container |
| homarr | 2.5M | Dashboard |
| huntarr | 289M | Content search |
| jackett | 902K | Indexer |
| jelly-meilisearch | 125M | Search engine |
| jellyfin3 | 7.2G | Old Jellyfin install |
| jellystat | 9.5K | Jellyfin stats |
| kapowarr | 38K | Comic automation |
| karakeep-meili | 23K | Karaoke search |
| komga | 23M | Comic server |
| lazylibrarian | 163M | Book automation |
| n8n | 365M | Workflow automation |
| nextcloud | 1.7G | File sync |
| nzbget | 947M | Usenet downloader |
| obsidian | 4.9M | Note taking |
| ollama | 14G | LLM server |
| ombi | 1.6M | Request management |
| pihole | 443M | DNS ad blocking |
| planka | 15K | Kanban board |
| readeck | 6.0K | Read later |
| reiverr | 62K | Media dashboard |
| spottarr | 183M | Spotify automation |
| stashapp | 12K | Media organizer |
| suggestarr | 199K | Content suggestions |
| syncthing | 207M | File sync |
| task-md | 64K | Task manager |
| tdarr | 160M | Media transcoding |
| transmission | 33M | Torrent client |
| vaultwarden | 545K | Password manager |
| wekan | 63K | Kanban board |
| whisparr | 2.3G | Adult content automation |
| ytdl-sub | 206M | YouTube downloader |

## Key Findings

1. **All target Servarr apps found** in ix-apps storage
2. **Using SQLite databases** - All *arr apps use .db files, NOT PostgreSQL (contrary to plan assumptions)
3. **Sizes are manageable** - Largest is Prowlarr at 245M, Radarr at 443M, Sonarr at 178M
4. **Multiple Readarr instances** - readar, readar_ebooks, readar_audiobooks (need to determine which is active)
5. **Jellyfin partially migrated** - Has 2K in ix-apps (likely just config remnants), main data in /mnt/apps/apps/
6. **Old Jellyfin install** - jellyfin3 at 7.2G (old data to clean up)

## Database Type Summary

| App | Database | Files |
|-----|----------|-------|
| Sonarr | SQLite | sonarr.db (96M), logs.db (6M) |
| Radarr | SQLite | radarr.db (22M), logs.db (5M) |
| Prowlarr | SQLite | prowlarr.db (317M), logs.db (2.4M) |
| Bazarr | SQLite | TBD |
| Lidarr | SQLite | TBD |
| Readarr | SQLite | TBD |
| qBittorrent | Config files | settings, torrents |
| SABnzbd | SQLite + Config | TBD |
| Jellyseerr | SQLite | TBD |
| Recyclarr | YAML configs | No database |

## Total ix-apps Storage

Approximate total: **35GB** across 62 apps

Target Servarr apps total: **~2.7GB** (much smaller than expected)

## Migration Implications

1. **Simpler than planned** - No PostgreSQL migrations needed (all SQLite)
2. **Fast migration** - Total data to migrate is only ~2.7GB
3. **Low risk** - Can stop containers, copy data, update mounts, restart quickly
4. **Readarr confusion** - Need to determine which Readarr instance(s) are actually in use
5. **Cleanup opportunity** - Can remove old jellyfin3, nzbget, transmission after migration
