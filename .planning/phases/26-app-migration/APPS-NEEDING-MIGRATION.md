# Apps Still Needing Migration to /mnt/apps/apps/

**Total:** 19 apps still using `/mnt/.ix-apps/` paths

---

## HIGH PRIORITY - Servarr Ecosystem (6 apps)
**Migrate These First - Phase 27**

1. **core-SuggestArr**
   - `/mnt/.ix-apps/app_mounts/suggestarr/config`

2. **core-audiobookrequest**
   - `/mnt/.ix-apps/app_mounts/audiobookrequest/config`

3. **core-huntarr**
   - `/mnt/.ix-apps/app_mounts/huntarr/config`

4. **core-decluttarr**
   - `/mnt/.ix-apps/app_mounts/decluttarr/config.yaml`

5. **core-homarr** ⚠️ SPECIAL CASE
   - `/mnt/.ix-apps/app_configs/servarr/versions/1.0.0/templates/rendered/homarr/appdata`
   - Uses app_configs instead of app_mounts (unusual)

6. **core-whisparr**
   - `/mnt/.ix-apps/app_mounts/whisparr/config`
   - `/mnt/.ix-apps/app_mounts/whisparr/data`

---

## MEDIUM PRIORITY - Download & DMZ Apps (4 apps)
**Migrate Second - Phase 28**

7. **dmz-ytdl-sub**
   - `/mnt/.ix-apps/app_mounts/ytdl-sub/config`

8. **dmz-nzbget**
   - `/mnt/.ix-apps/app_mounts/nzbget/data`

9. **dmz-spottarr**
   - `/mnt/.ix-apps/app_mounts/spottarr/data`

10. **dmz-gluetun** (VPN container)
    - `/mnt/.ix-apps/app_mounts/gluetun`

---

## MEDIUM PRIORITY - Media Processing (1 app)
**Migrate Third - Phase 29**

11. **ix-tdarr-tdarr-1**
    - `/mnt/.ix-apps/app_mounts/tdarr/configs`
    - `/mnt/.ix-apps/app_mounts/tdarr/logs`
    - `/mnt/.ix-apps/app_mounts/tdarr/server`
    - `/mnt/.ix-apps/app_mounts/tdarr/transcodes`

---

## LOW PRIORITY - Infrastructure Apps (8 apps)
**Migrate When Convenient - Phase 30**

12. **ix-calibre-calibre-1**
    - `/mnt/.ix-apps/app_mounts/calibre/config`

13. **ix-calibre-web-calibre-web-1**
    - `/mnt/.ix-apps/app_mounts/calibre-web/config`

14. **ix-syncthing-syncthing-1**
    - `/mnt/.ix-apps/app_mounts/syncthing/config`

15. **ix-n8n-n8n-1**
    - `/mnt/.ix-apps/app_mounts/n8n/data`
    - Plus docker volumes for cache and tmp

16. **ix-n8n-postgres-1**
    - `/mnt/.ix-apps/app_mounts/n8n/postgres_data`
    - Plus docker volumes

17. **ix-n8n-redis-1**
    - `/mnt/.ix-apps/docker/volumes/ix-n8n_redis-data/_data`

18. **ix-vaultwarden-vaultwarden-1**
    - `/mnt/.ix-apps/app_mounts/vaultwarden/data`

19. **ix-vaultwarden-postgres-1**
    - `/mnt/.ix-apps/app_mounts/vaultwarden/postgres_data`
    - Plus docker volumes

---

## OPTIONAL - Mixed Path Cleanup (2 apps)
**These are already mostly migrated, just need cleanup**

20. **media-komga**
    - Config and data already in `/mnt/apps/apps/komga/`
    - Only has `/tmp` in ix-apps docker volumes
    - Cleanup when convenient

21. **searxng**
    - Config already in `/mnt/apps/apps/searxng/`
    - Only has cache in ix-apps docker volumes
    - Cleanup when convenient

---

## Migration Strategy

### Phase 27 (Immediate)
- Focus on servarr ecosystem apps
- These should have been part of Phase 26
- 6 apps to migrate

### Phase 28 (Within 1 week)
- Migrate DMZ download infrastructure
- Includes VPN container (gluetun)
- 4 apps to migrate

### Phase 29 (Within 2 weeks)
- Migrate media processing (tdarr)
- 1 app to migrate

### Phase 30 (Within 1 month)
- Migrate remaining infrastructure apps
- 8 apps to migrate
- Can be done gradually

### Total Migration Workload
- **19 apps** need full migration
- **2 apps** need cleanup only
- **36 apps** already correctly migrated ✅
- **Phase 26 apps** all verified correct ✅
