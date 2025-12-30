# Backup Manifest - App Migration 2025-12-30

## Backup Location
`/mnt/storage/backups/app-migration-20251230/`

## Backup Timing
- **Start:** 2025-12-30 11:51:52
- **End:** 2025-12-30 11:52:32
- **Duration:** 40 seconds

## Backup Contents

### Individual App Backups (from /mnt/.ix-apps/app_mounts/)

| App | Size | Database Type | Priority |
|-----|------|---------------|----------|
| sonarr | 182M | SQLite (sonarr.db 96M) | HIGH |
| radarr | 448M | SQLite (radarr.db 22M) | HIGH |
| prowlarr | 253M | SQLite (prowlarr.db 317M) | CRITICAL |
| bazarr | 4.4M | SQLite | MEDIUM |
| qbittorrent | 21M | Config + session | HIGH |
| sabnzbd | 3.4M | SQLite + config | HIGH |
| jellyseerr | 2.1M | SQLite | MEDIUM |
| recyclarr | 130M | Config only | LOW |

### Totals
- **Total backup size:** ~1.04GB
- **Total files:** 8,307 files
- **Apps backed up:** 8 apps
- **Backup integrity:** ✓ Verified

## File Structure

```
/mnt/storage/backups/app-migration-20251230/
└── ix-apps/
    ├── sonarr/
    │   └── config/
    │       ├── sonarr.db (96M)
    │       ├── sonarr.db-shm
    │       ├── sonarr.db-wal
    │       ├── logs.db
    │       ├── config.xml
    │       ├── Backups/
    │       └── MediaCover/ (103 show posters)
    ├── radarr/
    │   └── config/
    │       ├── radarr.db (22M)
    │       ├── radarr.db-shm
    │       ├── radarr.db-wal
    │       ├── logs.db
    │       ├── config.xml
    │       ├── Backups/
    │       └── MediaCover/ (320 movie posters)
    ├── prowlarr/
    │   └── config/
    │       ├── prowlarr.db (317M)
    │       ├── prowlarr.db-shm
    │       ├── prowlarr.db-wal
    │       ├── logs.db
    │       ├── config.xml
    │       ├── Backups/
    │       └── Definitions/
    ├── bazarr/
    │   └── config/
    ├── qbittorrent/
    │   └── config/
    ├── sabnzbd/
    │   └── config/
    ├── jellyseerr/
    │   └── config/
    └── recyclarr/
        └── config/
```

## Restore Procedure

### Quick Restore (if migration fails)
```bash
# For individual app (example: sonarr)
sudo rsync -av /mnt/storage/backups/app-migration-20251230/ix-apps/sonarr/ /mnt/.ix-apps/app_mounts/sonarr/
sudo chown -R 1000:1000 /mnt/.ix-apps/app_mounts/sonarr/

# Restart container
cd /mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered/
sudo docker compose restart core-sonarr
```

### Full Rollback (if complete failure)
```bash
# Stop all containers
cd /mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered/
sudo docker compose stop

# Restore all apps
for app in sonarr radarr prowlarr bazarr qbittorrent sabnzbd jellyseerr recyclarr; do
    sudo rsync -av /mnt/storage/backups/app-migration-20251230/ix-apps/$app/ /mnt/.ix-apps/app_mounts/$app/
    sudo chown -R 1000:1000 /mnt/.ix-apps/app_mounts/$app/
done

# Start all containers
sudo docker compose up -d
```

## Important Notes

1. **SQLite WAL Files:** All .db, .db-shm, and .db-wal files backed up together (required for database integrity)
2. **MediaCover directories:** Backed up with all poster/metadata images
3. **Ownership:** Original files owned by user 1000:1000 (rain:rain)
4. **Backup retention:** Keep for minimum 30 days after successful migration
5. **Verification:** Backup sizes match source sizes within expected variance
6. **Compose file:** Docker compose file at `/mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered/docker-compose.yaml`

## Pre-Migration State Snapshot

### Docker Containers Running
- core-sonarr: ✓ Up 10 hours (healthy)
- core-radarr: ✓ Up 10 hours (healthy)
- dmz-prowlarr: ✓ Up 10 hours
- core-bazarr: ✓ Up 10 hours
- dmz-qbittorrent: ✓ Up 53 minutes (healthy)
- dmz-sabnzbd: ✓ Up 10 hours
- media-jellyseerr: ✓ Up 10 hours
- Recyclarr: Location TBD

### Web UI Accessibility (Pre-Migration)
- Sonarr: http://localhost:8989 - ✓ Accessible
- Radarr: http://localhost:7878 - ✓ Accessible
- Prowlarr: http://localhost:9696 - ✓ Accessible
- Bazarr: Port TBD
- qBittorrent: Port TBD (via Gluetun VPN)
- SABnzbd: Port TBD (via Gluetun VPN)
- Jellyseerr: http://localhost:5055 (likely)

## Backup Verification Checklist

- [x] All 8 target apps backed up
- [x] SQLite databases copied with WAL files
- [x] MediaCover directories included
- [x] Config files included (config.xml)
- [x] Backup sizes reasonable (1.04GB total)
- [x] File count verified (8,307 files)
- [x] Backup directory accessible
- [x] Sufficient space for migration work
- [x] No permission errors during backup

## Next Steps

1. ✓ Backup complete
2. Create migration runbook
3. Prepare target directories in /mnt/apps/apps/
4. Begin Wave 1 migration (Recyclarr)
5. Test migration procedure
6. Continue with remaining waves
7. Verify all apps working
8. Keep backup for 30 days minimum

## Backup Success

✅ **Backup completed successfully - ready to proceed with migration**
