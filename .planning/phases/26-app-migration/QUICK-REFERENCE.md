# Phase 26 App Migration - Quick Reference Card

**Migration Status:** ✅ COMPLETE (2025-12-30)
**Apps Migrated:** 7 of 7 running apps
**Success Rate:** 100%

---

## Current App Locations

All apps now run from: `/mnt/apps/apps/<appname>/config/`

```
/mnt/apps/apps/
├── bazarr/config/        (4.2M)
├── jellyseerr/config/    (2.0M)
├── prowlarr/config/      (245M)
├── qbittorrent/config/   (21M)
├── radarr/config/        (443M)
├── sabnzbd/config/       (3.1M)
└── sonarr/config/        (178M)
```

---

## Web UI Access

- **Prowlarr:** http://waterbug.lan:9696
- **Sonarr:** http://waterbug.lan:8989
- **Radarr:** http://waterbug.lan:7878
- **Bazarr:** http://waterbug.lan:6767
- **qBittorrent:** http://waterbug.lan:30024 (via VPN)
- **SABnzbd:** http://waterbug.lan:8085 (via VPN)
- **Jellyseerr:** http://waterbug.lan:5055

---

## Quick Status Checks

**All containers:**
```bash
ssh waterbug.lan "sudo docker ps | grep -E '(sonarr|radarr|prowlarr|bazarr|qbit|sab|jellyseerr)'"
```

**Check specific app:**
```bash
ssh waterbug.lan "sudo docker ps | grep <appname>"
ssh waterbug.lan "sudo docker logs <container-name> --tail 50"
```

**Verify using new paths:**
```bash
ssh waterbug.lan "sudo docker inspect <container-name> | grep '/mnt/apps/apps'"
```

---

## Container Names

- `core-sonarr`
- `core-radarr`
- `core-bazarr`
- `dmz-prowlarr`
- `dmz-qbittorrent`
- `dmz-sabnzbd`
- `media-jellyseerr`

---

## Backup Information

**Location:** `/mnt/storage/backups/app-migration-20251230/`
**Size:** 1.04GB (8,307 files)
**Retention:** Until 2025-01-29 (minimum 30 days)

---

## Rollback Procedure

If issues occur:

1. Stop affected container:
   ```bash
   ssh waterbug.lan "cd /mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered && sudo docker compose stop <container-name>"
   ```

2. Restore docker-compose backup:
   ```bash
   ssh waterbug.lan "sudo cp /mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered/docker-compose.yaml.backup-20251230-115846 /mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered/docker-compose.yaml"
   ```

3. Restart container:
   ```bash
   ssh waterbug.lan "cd /mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered && sudo docker compose up -d <container-name>"
   ```

---

## Next Steps Timeline

**Immediate (0-24 hours):**
- Manual functional testing via web UIs
- Verify all app integrations working
- Test downloads and searches

**Short-term (1-7 days):**
- Daily monitoring for errors/issues
- Performance baseline comparison
- Track automated processes

**After 7 days (if stable):**
- Clean up old ix-apps data
- Reclaim ~1GB disk space
- Archive migration documentation

---

## Testing Priorities

1. **CRITICAL:** Prowlarr indexer searches and app sync
2. **HIGH:** Download clients (qBit/SAB) functionality
3. **HIGH:** Sonarr/Radarr searches and downloads
4. **MEDIUM:** Bazarr subtitle downloads
5. **MEDIUM:** Jellyseerr request submissions

---

## Documentation Files

Located in: `/home/rain/nix-config/.planning/phases/26-app-migration/`

- **SUMMARY.md** - Complete migration summary and results
- **TESTING-CHECKLIST.md** - Manual testing procedures
- **migration-log.md** - Detailed execution log
- **backup-manifest.md** - Backup details and restore procedures
- **MIGRATION-STATUS.md** - Discovery phase results
- **26-01-PLAN.md** - Original migration plan

---

## Current Status (as of 2025-12-30 12:20 CST)

```
core-bazarr: Up 6 minutes
core-radarr: Up 6 minutes (healthy)
core-sonarr: Up 7 minutes (healthy)
dmz-prowlarr: Up 8 minutes
dmz-qbittorrent: Up 10 minutes (healthy)
dmz-sabnzbd: Up 9 minutes
media-jellyseerr: Up 5 minutes
```

**All systems operational. Zero errors detected.**

---

## Common Operations

**Restart all apps:**
```bash
ssh waterbug.lan "cd /mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered && sudo docker compose restart"
```

**Restart specific app:**
```bash
ssh waterbug.lan "cd /mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered && sudo docker compose restart <container-name>"
```

**View logs (real-time):**
```bash
ssh waterbug.lan "sudo docker logs -f <container-name>"
```

**Check disk usage:**
```bash
ssh waterbug.lan "du -sh /mnt/apps/apps/*/config"
```

---

## Migration Success Metrics

- **Execution time:** 5 minutes (vs 6 hours estimated)
- **Downtime per app:** 30-60 seconds
- **Data integrity:** 100% (all files transferred)
- **Container health:** 100% (7/7 running)
- **Errors encountered:** 0
- **Rollbacks required:** 0

---

## Contact for Issues

If critical issues arise:
1. Check container logs first
2. Verify mount paths using docker inspect
3. Test rollback procedure if needed
4. Document issue in TESTING-CHECKLIST.md

---

**Quick Reference Card v1.0**
**Last Updated:** 2025-12-30 12:20 CST
