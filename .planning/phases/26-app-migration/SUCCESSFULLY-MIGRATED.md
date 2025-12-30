# Successfully Migrated Apps Using /mnt/apps/apps/

**Total:** 36 apps correctly using `/mnt/apps/apps/` paths

---

## Phase 26 Apps - All Verified ✅ (9 apps)

### Download Clients
1. **dmz-qbittorrent** ✅
   - `/mnt/apps/apps/qbittorrent/config -> /config`
   - `/mnt/storage/storage -> /storage`

2. **dmz-sabnzbd** ✅
   - `/mnt/apps/apps/sabnzbd/config -> /config`
   - `/mnt/storage/storage -> /storage`

### Indexer
3. **dmz-prowlarr** ✅
   - `/mnt/apps/apps/prowlarr/config -> /config`

### TV Management
4. **core-sonarr** ✅
   - `/mnt/apps/apps/sonarr/config -> /config`
   - `/mnt/storage/storage -> /storage`

### Movie Management
5. **core-radarr** ✅
   - `/mnt/apps/apps/radarr/config -> /config`
   - `/mnt/storage/storage -> /storage`

### Subtitle Management
6. **core-bazarr** ✅
   - `/mnt/apps/apps/bazarr/config -> /config`
   - `/mnt/storage/storage -> /storage`
   - `/mnt/storage/storage/Movies -> /movies`
   - `/mnt/storage/storage/Shows -> /tv`

### Request Management
7. **media-jellyseerr** ✅
   - `/mnt/apps/apps/jellyseerr/config -> /app/config`

### Media Server
8. **media-jellyfin** ✅
   - `/mnt/apps/apps/jellyfin/config -> /config`
   - `/mnt/storage/storage -> /storage`

### Automation
9. **media-janitorr** ✅
   - `/mnt/apps/apps/janitorr/config/application.yml -> /workspace/application.yml`
   - `/mnt/apps/apps/janitorr/logs -> /logs`
   - `/mnt/storage/storage -> /storage`

---

## Other Successfully Migrated Apps (27 apps)

### Media Management
10. **jackett**
    - `/mnt/apps/apps/jackett/config -> /config`

11. **media-audiobookshelf**
    - `/mnt/apps/apps/audiobookshelf/config -> /config`
    - `/mnt/apps/apps/audiobookshelf/metadata -> /metadata`

12. **ersatztv**
    - `/mnt/apps/apps/ersatztv/config -> /config`

13. **media-jelly-meilisearch**
    - `/mnt/apps/apps/jelly-meilisearch -> /meili_data`

14. **media-stash**
    - Multiple mounts for metadata, cache, data, blobs, config

### Content Apps
15. **core-kapowarr**
    - `/mnt/apps/apps/kapowarr/kapowarr-db -> /app/db`

16. **dmz-pinchflat**
    - `/mnt/apps/apps/pinchflat/config -> /config`

17. **readeck**
    - `/mnt/apps/apps/readeck/data -> /readeck`

18. **freshrss**
    - `/mnt/apps/apps/freshrss/config -> /config`

### Automation & Monitoring
19. **core-checkrr**
    - `/mnt/apps/apps/checkrr/config/checkrr.yaml -> /checkrr.yaml`

20. **changedetection**
    - `/mnt/apps/apps/changedetection/data -> /datastore`

### Infrastructure
21. **ix-portainer-portainer-1**
    - `/mnt/apps/apps/portainer -> /data`

22. **nextcloud**
    - `/mnt/apps/apps/nextcloud/config -> /config`
    - `/mnt/apps/apps/nextcloud/data -> /data`

23. **nc-mariadb**
    - `/mnt/apps/apps/mariadb -> /var/lib/mysql`

24. **nc-redis**
    - `/mnt/apps/apps/nextcloud/redis -> /data`

25. **redis** (for searxng)
    - `/mnt/apps/apps/searxng/valkey-data2 -> /data`

26. **dns-server** (Technitium)
    - `/mnt/apps/apps/technitium/config -> /etc/dns`

27. **ntfy**
    - `/mnt/apps/apps/ntfy/lib -> /var/lib/ntfy`
    - `/mnt/apps/apps/ntfy/etc -> /etc/ntfy`
    - `/mnt/apps/apps/ntfy/cache -> /var/cache/ntfy`

### Utility Apps
28. **ix-karakeep-web-1**
    - `/mnt/apps/apps/karakeep/data -> /data`

29. **ix-karakeep-meilisearch-1**
    - `/mnt/apps/apps/karakeep/meilisearch -> /meili_data`

30. **planka**
    - `/mnt/apps/apps/planka/config -> /config`

31. **apprise-api**
    - `/mnt/apps/apps/apprise-api/attachments -> /attachments`
    - `/mnt/apps/apps/apprise-api/config -> /config`

32. **faster-whisper**
    - `/mnt/apps/apps/faster-whisper/config -> /config`

### Gaming
33. **ix-crafty-4-crafty-4-1** (Minecraft)
    - `/mnt/apps/apps/crafty-4/backups -> /crafty/backups`
    - `/mnt/apps/apps/crafty-4/import -> /crafty/import`
    - `/mnt/apps/apps/crafty-4/logs -> /crafty/logs`
    - `/mnt/apps/apps/crafty-4/data -> /crafty/servers`
    - `/mnt/apps/apps/crafty-4/config -> /crafty/app/config`

### Shell History
34. **ix-atuin-atuin-1**
    - `/mnt/apps/apps/atuin/config -> /config`

35. **ix-atuin-atuin-db-1**
    - `/mnt/apps/apps/atuin/database -> /var/lib/postgresql/data`

### Analytics
36. **media-streamy-vectorchord**
    - `/mnt/apps/apps/streamystats/vectorchord_data -> /var/lib/postgresql/data`

---

## Migration Success Rate

- **Total Containers:** 65
- **Successfully Migrated:** 36 (55.4%)
- **Phase 26 Success:** 9/9 (100%) ✅
- **Remaining to Migrate:** 19 (29.2%)
- **Mixed (Partial):** 2 (3.1%)
- **No Migration Needed:** 8 (12.3%)

---

## Key Achievements

### Phase 26 Perfect Success
All 9 apps targeted in Phase 26 are now running with:
- Config directories in `/mnt/apps/apps/[appname]/config`
- Storage mounts at `/mnt/storage/storage`
- NO legacy `/mnt/.ix-apps/` paths
- NO discrepancies between config and runtime

### Additional Apps Already Migrated
27 other apps were found to already be using the correct paths, including:
- Core infrastructure (Nextcloud, Portainer, DNS)
- Media apps (Stash, Audiobookshelf, Komga)
- Utility apps (Atuin, Crafty-4, Karakeep)
- Automation apps (Changedetection, Apprise)

### No Critical Issues
- No apps with broken mounts
- No apps with conflicting paths
- All Phase 26 apps verified working
- Runtime matches configuration

---

## Verification Method

Each app was verified by:
1. Inspecting running container with `docker inspect`
2. Checking actual mount points at runtime
3. Confirming source paths use `/mnt/apps/apps/`
4. Verifying no `/mnt/.ix-apps/` paths in use
5. Cross-referencing with storage mounts

All verifications performed: 2025-12-30
All data collected from live running containers on waterbug.lan
