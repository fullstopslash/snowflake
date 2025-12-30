# Quick Reference - App Migration Audit Status

**Audit Date:** 2025-12-30
**System:** waterbug.lan

---

## Phase 26 Apps - All Verified ✅

| App | Status | Config Path | Notes |
|-----|--------|-------------|-------|
| qbittorrent | ✅ MIGRATED | `/mnt/apps/apps/qbittorrent/config` | Perfect |
| sabnzbd | ✅ MIGRATED | `/mnt/apps/apps/sabnzbd/config` | Perfect |
| prowlarr | ✅ MIGRATED | `/mnt/apps/apps/prowlarr/config` | Perfect |
| sonarr | ✅ MIGRATED | `/mnt/apps/apps/sonarr/config` | Perfect |
| radarr | ✅ MIGRATED | `/mnt/apps/apps/radarr/config` | Perfect |
| bazarr | ✅ MIGRATED | `/mnt/apps/apps/bazarr/config` | Perfect |
| jellyseerr | ✅ MIGRATED | `/mnt/apps/apps/jellyseerr/config` | Perfect |
| jellyfin | ✅ MIGRATED | `/mnt/apps/apps/jellyfin/config` | Perfect |
| janitorr | ✅ MIGRATED | `/mnt/apps/apps/janitorr/config` | Perfect |

---

## Apps Needing Migration

### 🔴 HIGH PRIORITY - Phase 27 (Servarr Apps)

| App | Current Path | Priority | Phase |
|-----|--------------|----------|-------|
| core-SuggestArr | `/mnt/.ix-apps/app_mounts/suggestarr/` | 🔴 HIGH | 27 |
| core-audiobookrequest | `/mnt/.ix-apps/app_mounts/audiobookrequest/` | 🔴 HIGH | 27 |
| core-huntarr | `/mnt/.ix-apps/app_mounts/huntarr/` | 🔴 HIGH | 27 |
| core-decluttarr | `/mnt/.ix-apps/app_mounts/decluttarr/` | 🔴 HIGH | 27 |
| core-homarr | `/mnt/.ix-apps/app_configs/servarr/...` | 🔴 HIGH | 27 |
| core-whisparr | `/mnt/.ix-apps/app_mounts/whisparr/` | 🔴 HIGH | 27 |

### 🟡 MEDIUM PRIORITY - Phase 28 (DMZ Apps)

| App | Current Path | Priority | Phase |
|-----|--------------|----------|-------|
| dmz-ytdl-sub | `/mnt/.ix-apps/app_mounts/ytdl-sub/` | 🟡 MEDIUM | 28 |
| dmz-nzbget | `/mnt/.ix-apps/app_mounts/nzbget/` | 🟡 MEDIUM | 28 |
| dmz-spottarr | `/mnt/.ix-apps/app_mounts/spottarr/` | 🟡 MEDIUM | 28 |
| dmz-gluetun | `/mnt/.ix-apps/app_mounts/gluetun/` | 🟡 MEDIUM | 28 |

### 🟡 MEDIUM PRIORITY - Phase 29 (Media Processing)

| App | Current Path | Priority | Phase |
|-----|--------------|----------|-------|
| ix-tdarr-tdarr-1 | `/mnt/.ix-apps/app_mounts/tdarr/` | 🟡 MEDIUM | 29 |

### 🟢 LOW PRIORITY - Phase 30 (Infrastructure)

| App | Current Path | Priority | Phase |
|-----|--------------|----------|-------|
| ix-calibre-calibre-1 | `/mnt/.ix-apps/app_mounts/calibre/` | 🟢 LOW | 30 |
| ix-calibre-web-calibre-web-1 | `/mnt/.ix-apps/app_mounts/calibre-web/` | 🟢 LOW | 30 |
| ix-syncthing-syncthing-1 | `/mnt/.ix-apps/app_mounts/syncthing/` | 🟢 LOW | 30 |
| ix-n8n-n8n-1 | `/mnt/.ix-apps/app_mounts/n8n/` | 🟢 LOW | 30 |
| ix-n8n-postgres-1 | `/mnt/.ix-apps/app_mounts/n8n/` | 🟢 LOW | 30 |
| ix-n8n-redis-1 | `/mnt/.ix-apps/docker/volumes/...` | 🟢 LOW | 30 |
| ix-vaultwarden-vaultwarden-1 | `/mnt/.ix-apps/app_mounts/vaultwarden/` | 🟢 LOW | 30 |
| ix-vaultwarden-postgres-1 | `/mnt/.ix-apps/app_mounts/vaultwarden/` | 🟢 LOW | 30 |

---

## Migration Progress

```
Total Apps: 65
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Migrated (apps):     36 ████████████████████████░░░░░░░░░░░░░░░  55%
⚠️  Need Migration:     19 ████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░  29%
🔀 Mixed Paths:          2 █░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   3%
⚪ No Mounts:            8 ████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  12%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Next Phase Summary

### Phase 27 - Immediate Action Required
- **Apps:** 6 servarr apps
- **Timeline:** Start ASAP
- **Risk:** Low (follow Phase 26 pattern)
- **Apps:**
  1. core-SuggestArr
  2. core-audiobookrequest
  3. core-huntarr
  4. core-decluttarr
  5. core-homarr ⚠️ (special case)
  6. core-whisparr

### Expected Outcome After Phase 27
- Migrated apps: 42 (65%)
- Remaining: 13 (20%)
- Servarr ecosystem: 100% complete ✅

---

## Container Categories

### By Migration Status
- **✅ Using /mnt/apps/apps/:** 36 apps
- **⚠️ Using /mnt/.ix-apps/:** 19 apps
- **🔀 Mixed paths:** 2 apps
- **⚪ No relevant mounts:** 8 apps

### By Application Type
- **Media Management:** 13 apps (8 migrated, 5 not)
- **Download Clients:** 6 apps (2 migrated, 4 not)
- **Infrastructure:** 15 apps (7 migrated, 8 not)
- **Content/Reading:** 5 apps (3 migrated, 2 not)
- **Automation:** 4 apps (3 migrated, 1 not)
- **Other:** 22 apps (13 migrated, 9 not)

### By Priority
- **🔴 HIGH (Phase 27):** 6 apps - Servarr ecosystem
- **🟡 MEDIUM (Phases 28-29):** 5 apps - Download & processing
- **🟢 LOW (Phase 30):** 8 apps - Infrastructure
- **✅ DONE:** 36 apps - Already migrated
- **🔀 OPTIONAL:** 2 apps - Cleanup only

---

## Quick Commands

### Check specific app:
```bash
ssh waterbug.lan "sudo docker inspect <container-name> --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}'"
```

### Check all apps using ix-apps:
```bash
ssh waterbug.lan "sudo docker ps -q | xargs -I {} docker inspect {} --format='{{.Name}}: {{range .Mounts}}{{if contains .Source \"ix-apps\"}}{{.Source}}{{end}}{{end}}'"
```

### List all running containers:
```bash
ssh waterbug.lan "sudo docker ps --format '{{.Names}}' | sort"
```

---

## Files in This Directory

1. **EXECUTIVE-SUMMARY.md** - High-level overview and key findings
2. **AUDIT-REPORT.md** - Comprehensive detailed audit report
3. **APPS-NEEDING-MIGRATION.md** - List of apps to migrate with priorities
4. **SUCCESSFULLY-MIGRATED.md** - List of all correctly migrated apps
5. **QUICK-REFERENCE-AUDIT.md** - This file - quick lookup tables

---

**Last Updated:** 2025-12-30
**Next Review:** After Phase 27 completion
**Status:** Phase 26 Complete ✅ | Phase 27 Ready to Start 🔜
