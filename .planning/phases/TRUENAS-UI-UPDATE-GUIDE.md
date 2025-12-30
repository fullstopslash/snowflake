# TrueNAS UI Configuration Update Guide

Complete guide for updating 9 apps to use `/mnt/apps/apps/` instead of ix-apps paths.

**Last Updated:** 2025-12-30

---

## Table of Contents

1. [Overview](#overview)
2. [Pre-Update Checklist](#pre-update-checklist)
3. [General Update Procedure](#general-update-procedure)
4. [App-Specific Instructions](#app-specific-instructions)
5. [Verification Steps](#verification-steps)
6. [Priority Order](#priority-order)
7. [Troubleshooting](#troubleshooting)

---

## Overview

### What We're Doing

Updating TrueNAS app configurations to point to the new consolidated storage location:
- **OLD PATH:** `/mnt/.ix-apps/app_mounts/[appname]/`
- **NEW PATH:** `/mnt/apps/apps/[appname]/`

### Why This Matters

- Data is already at new location (migrated via migration.sh)
- TrueNAS UI still references old ix-apps paths
- Apps won't see their data until configs are updated
- Some use docker volumes that need converting to bind mounts

### Apps Requiring Updates

| # | App Name | Status | Complexity | Containers |
|---|----------|--------|------------|------------|
| 1 | syncthing | STOPPED | Simple | 1 |
| 2 | calibre | STOPPED | Simple | 1 |
| 3 | calibre-web | STOPPED | Simple | 1 |
| 4 | vaultwarden | STOPPED | Medium | 1 |
| 5 | vaultwarden-postgres | STOPPED | Medium | 1 |
| 6 | n8n | STOPPED | Complex | 1 |
| 7 | n8n-postgres | STOPPED | Complex | 1 |
| 8 | n8n-redis | STOPPED | Complex | 1 |
| 9 | spottarr | RUNNING | Simple | 1 |

---

## Pre-Update Checklist

### Before You Begin

- [ ] All apps are stopped (except spottarr - stop before updating)
- [ ] Data verified at `/mnt/apps/apps/[appname]/` locations
- [ ] SSH access to waterbug.lan available
- [ ] TrueNAS UI accessible via web browser
- [ ] Backup of current configurations (export app configs if possible)

### Verify Data Locations

```bash
# SSH into TrueNAS
ssh waterbug.lan

# Check data exists at new locations
ls -lh /mnt/apps/apps/

# Should show directories for:
# syncthing, calibre, calibre-web, n8n, vaultwarden
```

### Critical Permissions Check

```bash
# All app directories should be owned by apps:apps
ssh waterbug.lan "ls -la /mnt/apps/apps/"

# If permissions are wrong, fix with:
ssh waterbug.lan "chown -R apps:apps /mnt/apps/apps/"
```

---

## General Update Procedure

### Standard Steps for Each App

#### 1. Access App Configuration

1. Open TrueNAS web UI (https://waterbug.lan or http://waterbug.lan:81)
2. Navigate to **Apps** in left sidebar
3. Find the app in the list
4. Click the **three dots menu** (⋮) on the right side of the app
5. Select **Edit**

#### 2. Locate Storage Configuration

1. In the edit screen, scroll down to find **Storage** section
2. May be labeled as:
   - "Storage"
   - "Storage and Persistence"
   - "Additional Storage"
   - "Host Path Volumes"

#### 3. Update Mount Paths

For each storage entry:

1. Look for **Host Path** field
2. Current value will be: `/mnt/.ix-apps/app_mounts/[appname]/[directory]`
3. Change to: `/mnt/apps/apps/[appname]/[directory]`
4. Ensure **Type** is set to "Host Path" (not "ixVolume" or "Volume")

#### 4. Convert Docker Volumes (If Applicable)

If storage shows as "ixVolume" or "Volume":

1. Change **Type** dropdown from "ixVolume/Volume" to "Host Path"
2. Set **Host Path** to: `/mnt/apps/apps/[appname]/[directory]`
3. Keep **Mount Path** (container internal path) unchanged

#### 5. Save and Verify

1. Click **Save** at bottom of page
2. Wait for config to update (may take 10-30 seconds)
3. App will remain stopped
4. Proceed to verification before starting

---

## App-Specific Instructions

### 1. Syncthing (Simple)

**Status:** Stopped
**Containers:** 1
**Complexity:** Simple - Single path change

#### Current Configuration
```
Host Path: /mnt/.ix-apps/app_mounts/syncthing/config
Mount Path: /var/syncthing (in container)
```

#### New Configuration
```
Host Path: /mnt/apps/apps/syncthing/config
Mount Path: /var/syncthing (unchanged)
```

#### Steps
1. Apps → syncthing → Edit
2. Scroll to **Storage** section
3. Find "Config Storage" or similar entry
4. Update **Host Path**:
   - FROM: `/mnt/.ix-apps/app_mounts/syncthing/config`
   - TO: `/mnt/apps/apps/syncthing/config`
5. Save
6. Start app
7. Verify startup in logs

#### Verification
```bash
# Check container is running
ssh waterbug.lan "docker ps | grep syncthing"

# Verify mount
ssh waterbug.lan "docker inspect ix-syncthing-syncthing-1 --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}' | grep syncthing"

# Should show: /mnt/apps/apps/syncthing/config -> /var/syncthing
```

---

### 2. Calibre (Simple)

**Status:** Stopped
**Containers:** 1
**Complexity:** Simple - Single path change

#### Current Configuration
```
Host Path: /mnt/.ix-apps/app_mounts/calibre/config
Mount Path: /config (in container)
Data size: 9.6M
```

#### New Configuration
```
Host Path: /mnt/apps/apps/calibre/config
Mount Path: /config (unchanged)
```

#### Steps
1. Apps → calibre → Edit
2. Scroll to **Storage** section
3. Find "Config Storage" entry
4. Update **Host Path**:
   - FROM: `/mnt/.ix-apps/app_mounts/calibre/config`
   - TO: `/mnt/apps/apps/calibre/config`
5. Save
6. Start app
7. Check web UI accessible

#### Verification
```bash
# Check container
ssh waterbug.lan "docker ps | grep calibre"

# Verify mount
ssh waterbug.lan "docker inspect ix-calibre-calibre-1 --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}' | grep calibre"

# Should show: /mnt/apps/apps/calibre/config -> /config
```

---

### 3. Calibre-Web (Simple)

**Status:** Stopped
**Containers:** 1
**Complexity:** Simple - Single path change

#### Current Configuration
```
Host Path: /mnt/.ix-apps/app_mounts/calibre-web/config
Mount Path: /config (in container)
```

#### New Configuration
```
Host Path: /mnt/apps/apps/calibre-web/config
Mount Path: /config (unchanged)
```

#### Steps
1. Apps → calibre-web → Edit
2. Scroll to **Storage** section
3. Find "Config Storage" entry
4. Update **Host Path**:
   - FROM: `/mnt/.ix-apps/app_mounts/calibre-web/config`
   - TO: `/mnt/apps/apps/calibre-web/config`
5. Save
6. Start app
7. Verify web UI loads

#### Verification
```bash
# Check container
ssh waterbug.lan "docker ps | grep calibre-web"

# Verify mount
ssh waterbug.lan "docker inspect ix-calibre-web-calibre-web-1 --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}' | grep calibre-web"

# Should show: /mnt/apps/apps/calibre-web/config -> /config
```

#### Special Notes
- Calibre-Web may need to be pointed at Calibre's library
- Library path might also need updating if it references old paths
- Check Settings → Basic Configuration → Location of Calibre database

---

### 4. Vaultwarden (Medium)

**Status:** Stopped
**Containers:** 1
**Complexity:** Medium - Critical password manager

#### Current Configuration
```
Host Path: /mnt/.ix-apps/app_mounts/vaultwarden/data
Mount Path: /data (in container)
Data size: 544K
```

#### New Configuration
```
Host Path: /mnt/apps/apps/vaultwarden/data
Mount Path: /data (unchanged)
```

#### Steps
1. Apps → vaultwarden → Edit
2. Scroll to **Storage** section
3. Find "Data Storage" entry
4. Update **Host Path**:
   - FROM: `/mnt/.ix-apps/app_mounts/vaultwarden/data`
   - TO: `/mnt/apps/apps/vaultwarden/data`
5. Save
6. Start app
7. **CRITICAL:** Test login immediately

#### Verification
```bash
# Check container
ssh waterbug.lan "docker ps | grep vaultwarden"

# Verify mount
ssh waterbug.lan "docker inspect ix-vaultwarden-vaultwarden-1 --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}' | grep vaultwarden"

# Should show: /mnt/apps/apps/vaultwarden/data -> /data

# Check db.sqlite3 exists
ssh waterbug.lan "ls -lh /mnt/apps/apps/vaultwarden/data/db.sqlite3"
```

#### Critical Post-Update Tests
1. Access Vaultwarden web UI
2. Attempt to log in with existing account
3. Verify vault data is present
4. Test creating a new item
5. Test syncing with mobile/desktop clients

#### Rollback Plan
If login fails:
1. Stop vaultwarden
2. Edit config back to old path
3. Investigate data migration issue
4. DO NOT proceed with vaultwarden-postgres until main app works

---

### 5. Vaultwarden-Postgres (Medium)

**Status:** Stopped
**Containers:** 1
**Complexity:** Medium - PostgreSQL requires special handling

#### Current Configuration
```
Host Path: /mnt/.ix-apps/app_mounts/vaultwarden/postgres_data
Mount Path: /var/lib/postgresql/data (in container)
Data size: 15M
```

#### New Configuration
```
Host Path: /mnt/apps/apps/vaultwarden/postgres
Mount Path: /var/lib/postgresql/data (unchanged)
```

#### Important PostgreSQL Notes

**CRITICAL:** PostgreSQL containers often need:
1. `PGDATA` environment variable set to `/var/lib/postgresql/data/pgdata`
2. Proper permissions (UID 999, GID 999 or postgres:postgres)
3. Directory must be empty on first init OR contain valid PostgreSQL data

#### Steps
1. Apps → vaultwarden → Edit (may be same app as main vaultwarden)
2. Look for **postgres** or **database** container configuration
3. Find **Storage** section for postgres
4. Update **Host Path**:
   - FROM: `/mnt/.ix-apps/app_mounts/vaultwarden/postgres_data`
   - TO: `/mnt/apps/apps/vaultwarden/postgres`
5. Check **Environment Variables** section
6. Verify `PGDATA` is set (if not, add it):
   - Variable: `PGDATA`
   - Value: `/var/lib/postgresql/data/pgdata`
7. Save
8. Start container
9. Monitor logs for PostgreSQL startup

#### Verification
```bash
# Check container
ssh waterbug.lan "docker ps | grep vaultwarden-postgres"

# Verify mount
ssh waterbug.lan "docker inspect ix-vaultwarden-postgres-1 --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}' | grep postgres"

# Should show: /mnt/apps/apps/vaultwarden/postgres -> /var/lib/postgresql/data

# Check PostgreSQL logs
ssh waterbug.lan "docker logs ix-vaultwarden-postgres-1 --tail 50"

# Should see: "database system is ready to accept connections"
```

#### Check Database Integrity
```bash
# Connect to database
ssh waterbug.lan "docker exec -it ix-vaultwarden-postgres-1 psql -U vaultwarden -d vaultwarden"

# Run inside postgres shell:
# \dt                    -- List tables
# SELECT COUNT(*) FROM users;  -- Check user count
# \q                     -- Quit
```

---

### 6. n8n (Complex)

**Status:** Stopped
**Containers:** 3 (n8n, n8n-postgres, n8n-redis)
**Complexity:** Complex - Multi-container stack

#### Container 1: n8n Main

##### Current Configuration
```
Host Path: /mnt/.ix-apps/app_mounts/n8n/data
Mount Path: /home/node/.n8n (in container)
Data size: 364M
```

##### New Configuration
```
Host Path: /mnt/apps/apps/n8n/data
Mount Path: /home/node/.n8n (unchanged)
```

##### Steps
1. Apps → n8n → Edit
2. Find **Storage** section for main n8n container
3. Look for "Data Storage" or ".n8n directory" entry
4. Update **Host Path**:
   - FROM: `/mnt/.ix-apps/app_mounts/n8n/data`
   - TO: `/mnt/apps/apps/n8n/data`
5. **DO NOT SAVE YET** - Continue to postgres and redis sections

---

#### Container 2: n8n-postgres

##### Current Configuration
```
Host Path: /mnt/.ix-apps/app_mounts/n8n/postgres_data
Mount Path: /var/lib/postgresql/data (in container)
Data size: 23M
```

##### New Configuration
```
Host Path: /mnt/apps/apps/n8n/postgres
Mount Path: /var/lib/postgresql/data (unchanged)
Environment: PGDATA=/var/lib/postgresql/data/pgdata
```

##### Steps (Still in same Edit dialog)
1. Scroll to **postgres** container storage section
2. Find postgres data volume entry
3. Update **Host Path**:
   - FROM: `/mnt/.ix-apps/app_mounts/n8n/postgres_data`
   - TO: `/mnt/apps/apps/n8n/postgres`
4. Check **Environment Variables** for postgres
5. Ensure `PGDATA` exists:
   - Variable: `PGDATA`
   - Value: `/var/lib/postgresql/data/pgdata`
6. **DO NOT SAVE YET** - Continue to redis section

---

#### Container 3: n8n-redis

##### Current Configuration
```
Type: Docker Volume (ix-n8n_redis)
No host path binding
```

##### New Configuration
```
Type: Host Path
Host Path: /mnt/apps/apps/n8n/redis
Mount Path: /data (in container)
```

##### Pre-Update: Create Redis Directory
```bash
# SSH into TrueNAS
ssh waterbug.lan

# Create redis directory
mkdir -p /mnt/apps/apps/n8n/redis

# Set ownership
chown -R apps:apps /mnt/apps/apps/n8n/redis

# Set permissions (Redis needs write access)
chmod 755 /mnt/apps/apps/n8n/redis
```

##### Steps (Still in same Edit dialog)
1. Scroll to **redis** container storage section
2. Find redis storage entry (currently shows as "Volume" or "ixVolume")
3. Change **Type** from "Volume" to "Host Path"
4. Set **Host Path**: `/mnt/apps/apps/n8n/redis`
5. Set **Mount Path**: `/data` (standard redis data directory)
6. **NOW SAVE** - All three containers configured

---

#### n8n Stack - Final Save and Startup

1. Review all changes:
   - n8n data: `/mnt/apps/apps/n8n/data`
   - postgres: `/mnt/apps/apps/n8n/postgres`
   - redis: `/mnt/apps/apps/n8n/redis`
2. Click **Save**
3. Wait for configuration to update (may take 30-60 seconds)
4. Start the app
5. Monitor startup carefully (3 containers must start)

#### n8n Verification

```bash
# Check all 3 containers running
ssh waterbug.lan "docker ps | grep n8n"

# Should show:
# - ix-n8n-n8n-1
# - ix-n8n-postgres-1
# - ix-n8n-redis-1

# Verify n8n mounts
ssh waterbug.lan "docker inspect ix-n8n-n8n-1 --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}'"

# Should include: /mnt/apps/apps/n8n/data -> /home/node/.n8n

# Verify postgres mounts
ssh waterbug.lan "docker inspect ix-n8n-postgres-1 --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}'"

# Should include: /mnt/apps/apps/n8n/postgres -> /var/lib/postgresql/data

# Verify redis mounts
ssh waterbug.lan "docker inspect ix-n8n-redis-1 --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}'"

# Should include: /mnt/apps/apps/n8n/redis -> /data
```

#### n8n Functional Tests

1. Access n8n web UI (typically http://waterbug.lan:5678)
2. Log in with existing credentials
3. Verify workflows are present
4. Check workflow executions history
5. Test running a simple workflow
6. Verify credentials are accessible

#### n8n Troubleshooting

If n8n won't start:
```bash
# Check logs for each container
ssh waterbug.lan "docker logs ix-n8n-n8n-1 --tail 100"
ssh waterbug.lan "docker logs ix-n8n-postgres-1 --tail 100"
ssh waterbug.lan "docker logs ix-n8n-redis-1 --tail 100"

# Common issues:
# - Postgres: PGDATA not set or wrong permissions
# - Redis: Directory not created or no write permissions
# - n8n: Waiting for database (postgres must start first)
```

---

### 7. Spottarr (Simple + Migration Required)

**Status:** RUNNING (must stop before update)
**Containers:** 1
**Complexity:** Simple path change, but data needs migration first

#### Current Configuration
```
Host Path: /mnt/.ix-apps/app_mounts/spottarr/data
Mount Path: /config (in container)
Status: Currently running with old path
```

#### New Configuration
```
Host Path: /mnt/apps/apps/spottarr/data
Mount Path: /config (unchanged)
```

#### CRITICAL: Spottarr Data Migration First

**IMPORTANT:** Unlike other apps, spottarr data is still at old location and needs migration.

##### Pre-Update: Migrate Data
```bash
# SSH into TrueNAS
ssh waterbug.lan

# Stop spottarr
docker stop dmz-spottarr

# Create new directory
mkdir -p /mnt/apps/apps/spottarr

# Copy data (preserving permissions)
cp -a /mnt/.ix-apps/app_mounts/spottarr/data /mnt/apps/apps/spottarr/

# Set ownership
chown -R apps:apps /mnt/apps/apps/spottarr

# Verify copy
ls -lh /mnt/apps/apps/spottarr/data

# Check size matches
du -sh /mnt/.ix-apps/app_mounts/spottarr/data
du -sh /mnt/apps/apps/spottarr/data
```

#### Update Steps

1. In TrueNAS UI, Apps → spottarr → **Stop** (if not already stopped from SSH)
2. Click **Edit**
3. Scroll to **Storage** section
4. Find "Data" or "Config" storage entry
5. Update **Host Path**:
   - FROM: `/mnt/.ix-apps/app_mounts/spottarr/data`
   - TO: `/mnt/apps/apps/spottarr/data`
6. Save
7. Start app
8. Verify functionality

#### Verification
```bash
# Check container (may have different name - check docker ps)
ssh waterbug.lan "docker ps | grep spottarr"

# Verify mount
ssh waterbug.lan "docker inspect dmz-spottarr --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}' | grep spottarr"

# Should show: /mnt/apps/apps/spottarr/data -> /config
```

---

## Verification Steps

### Per-App Verification Checklist

After updating each app:

- [ ] Container shows as "Running" in TrueNAS UI
- [ ] Docker ps shows container active
- [ ] Mounts point to `/mnt/apps/apps/[appname]/`
- [ ] Logs show successful startup (no path errors)
- [ ] Web UI accessible (if applicable)
- [ ] Data is present and intact
- [ ] App functionality works (test key features)

### Container Status Check
```bash
# Check all app containers
ssh waterbug.lan "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' | grep -E 'syncthing|calibre|vaultwarden|n8n|spottarr'"
```

### Mount Point Verification
```bash
# Create verification script
cat << 'EOF' > /tmp/verify-mounts.sh
#!/bin/bash
apps=(
  "ix-syncthing-syncthing-1"
  "ix-calibre-calibre-1"
  "ix-calibre-web-calibre-web-1"
  "ix-vaultwarden-vaultwarden-1"
  "ix-vaultwarden-postgres-1"
  "ix-n8n-n8n-1"
  "ix-n8n-postgres-1"
  "ix-n8n-redis-1"
  "dmz-spottarr"
)

echo "Verifying mount points for all apps..."
echo "========================================"
for app in "${apps[@]}"; do
  echo ""
  echo "App: $app"
  docker inspect "$app" --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}' 2>/dev/null | grep -E "apps|ix-apps" || echo "Container not found or no mounts"
done
EOF

chmod +x /tmp/verify-mounts.sh

# Copy and run on TrueNAS
scp /tmp/verify-mounts.sh waterbug.lan:/tmp/
ssh waterbug.lan "bash /tmp/verify-mounts.sh"
```

### Data Integrity Checks

#### Syncthing
```bash
ssh waterbug.lan "ls -lh /mnt/apps/apps/syncthing/config/"
# Should show config.xml, cert.pem, key.pem, etc.
```

#### Calibre
```bash
ssh waterbug.lan "du -sh /mnt/apps/apps/calibre/config/"
# Should show ~9.6M
```

#### Vaultwarden
```bash
ssh waterbug.lan "ls -lh /mnt/apps/apps/vaultwarden/data/db.sqlite3"
# Should show database file
```

#### n8n
```bash
ssh waterbug.lan "ls -lh /mnt/apps/apps/n8n/data/"
# Should show .n8n database and workflow files (~364M total)
```

---

## Priority Order

### Recommended Update Sequence

Update apps in this order to minimize risk:

#### Phase 1: Simple Single-Path Apps (Low Risk)
1. **syncthing** - Simplest, single path, good test case
2. **calibre** - Single path, standalone
3. **calibre-web** - Single path, related to calibre

**After Phase 1:** Verify basic procedure works before proceeding.

#### Phase 2: Critical Apps (Medium Risk)
4. **vaultwarden** - Critical password manager, test thoroughly
5. **vaultwarden-postgres** - Database for vaultwarden

**After Phase 2:** Ensure vaultwarden fully functional before continuing.

#### Phase 3: Complex Multi-Container (Higher Risk)
6. **n8n** - Main app container
7. **n8n-postgres** - Database for n8n
8. **n8n-redis** - Redis for n8n (volume conversion required)

**After Phase 3:** Full n8n stack tested and working.

#### Phase 4: Migration Required (Moderate Risk)
9. **spottarr** - Requires data migration first, currently running

**Why This Order?**
- Start simple to validate procedure
- Build confidence before complex apps
- Critical apps (vaultwarden) done before most complex (n8n)
- Spottarr last as it needs migration and is currently running

### Time Estimates

| Phase | Apps | Est. Time | Risk Level |
|-------|------|-----------|------------|
| Phase 1 | 3 apps | 15-30 min | Low |
| Phase 2 | 2 apps | 20-30 min | Medium |
| Phase 3 | 3 apps | 30-45 min | Medium-High |
| Phase 4 | 1 app | 15-20 min | Medium |
| **Total** | **9 apps** | **1.5-2 hours** | - |

**Note:** Times include verification and testing. Faster if no issues encountered.

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: Container Won't Start After Update

**Symptoms:**
- Container shows "Stopped" or "Error" state
- Keeps restarting or crashes immediately

**Diagnosis:**
```bash
# Check logs
ssh waterbug.lan "docker logs [container-name] --tail 100"

# Common error messages:
# - "Permission denied" → Permissions issue
# - "No such file or directory" → Path doesn't exist
# - "Database not found" → Wrong database path
```

**Solutions:**

**A. Permission Denied**
```bash
# Fix ownership
ssh waterbug.lan "chown -R apps:apps /mnt/apps/apps/[appname]/"

# Fix permissions
ssh waterbug.lan "chmod -R 755 /mnt/apps/apps/[appname]/"

# For PostgreSQL specifically:
ssh waterbug.lan "chown -R 999:999 /mnt/apps/apps/[appname]/postgres/"
```

**B. Path Doesn't Exist**
```bash
# Verify path in config
# Go back to TrueNAS UI → Edit → Check exact path spelling

# Verify path exists
ssh waterbug.lan "ls -la /mnt/apps/apps/[appname]/"

# Create if missing
ssh waterbug.lan "mkdir -p /mnt/apps/apps/[appname]/[directory]"
```

**C. Wrong Mount Path**
```bash
# Rollback to old path temporarily
# TrueNAS UI → Edit → Change back to /mnt/.ix-apps/app_mounts/...
# Investigate why new path isn't working
```

---

#### Issue 2: PostgreSQL Container Won't Start

**Symptoms:**
- Postgres container crashes or restarts repeatedly
- Logs show "FATAL: data directory is invalid"
- Logs show "initdb: directory exists but is not empty"

**Diagnosis:**
```bash
# Check postgres logs
ssh waterbug.lan "docker logs [postgres-container] --tail 100"

# Check PGDATA environment variable
ssh waterbug.lan "docker inspect [postgres-container] --format '{{range .Config.Env}}{{println .}}{{end}}' | grep PGDATA"

# Check directory contents
ssh waterbug.lan "ls -la /mnt/apps/apps/[appname]/postgres/"
```

**Solutions:**

**A. PGDATA Not Set**
```
In TrueNAS UI → Edit → Environment Variables:
Add: PGDATA=/var/lib/postgresql/data/pgdata
```

**B. Wrong Permissions**
```bash
# PostgreSQL needs UID 999
ssh waterbug.lan "chown -R 999:999 /mnt/apps/apps/[appname]/postgres/"
ssh waterbug.lan "chmod 700 /mnt/apps/apps/[appname]/postgres/"
```

**C. Data Directory Issues**
```bash
# Check if pgdata subdirectory exists
ssh waterbug.lan "ls -la /mnt/apps/apps/[appname]/postgres/pgdata/"

# If missing or corrupt, may need to restore from backup
# Or check old location for original data
ssh waterbug.lan "ls -la /mnt/.ix-apps/app_mounts/[appname]/postgres_data/"
```

---

#### Issue 3: Data Not Visible in App

**Symptoms:**
- Container starts successfully
- App loads but data/configuration is missing
- Appears as fresh installation

**Diagnosis:**
```bash
# Check if data exists at new location
ssh waterbug.lan "ls -lah /mnt/apps/apps/[appname]/"

# Check container mount points
ssh waterbug.lan "docker inspect [container-name] --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}'"

# Check inside container
ssh waterbug.lan "docker exec [container-name] ls -la /config"
# Or wherever the mount point is
```

**Solutions:**

**A. Wrong Mount Path (Host Side)**
```
TrueNAS UI → Edit → Storage → Verify Host Path exactly matches:
/mnt/apps/apps/[appname]/[directory]
```

**B. Wrong Mount Path (Container Side)**
```
Check Mount Path (container internal path) matches original:
- Most apps: /config
- Syncthing: /var/syncthing
- n8n: /home/node/.n8n
- PostgreSQL: /var/lib/postgresql/data
```

**C. Data Still at Old Location**
```bash
# Check if data exists at old location
ssh waterbug.lan "ls -la /mnt/.ix-apps/app_mounts/[appname]/"

# If data is there, migration didn't happen
# Copy to new location:
ssh waterbug.lan "cp -a /mnt/.ix-apps/app_mounts/[appname]/* /mnt/apps/apps/[appname]/"
ssh waterbug.lan "chown -R apps:apps /mnt/apps/apps/[appname]/"
```

---

#### Issue 4: Redis Volume Conversion Fails

**Symptoms:**
- n8n-redis won't start after changing from Volume to Host Path
- Error about volume not found
- Redis data missing

**Diagnosis:**
```bash
# Check if directory exists
ssh waterbug.lan "ls -la /mnt/apps/apps/n8n/redis/"

# Check old docker volume
ssh waterbug.lan "docker volume ls | grep n8n"
```

**Solutions:**

**A. Directory Not Created**
```bash
ssh waterbug.lan "mkdir -p /mnt/apps/apps/n8n/redis"
ssh waterbug.lan "chown -R apps:apps /mnt/apps/apps/n8n/redis"
ssh waterbug.lan "chmod 755 /mnt/apps/apps/n8n/redis"
```

**B. Data Still in Docker Volume**
```bash
# Copy data from docker volume to host path
ssh waterbug.lan "docker run --rm -v ix-n8n_redis:/from -v /mnt/apps/apps/n8n/redis:/to alpine ash -c 'cd /from && cp -av . /to'"

# Set ownership
ssh waterbug.lan "chown -R apps:apps /mnt/apps/apps/n8n/redis"
```

**C. Wrong Mount Path in Container**
```
Ensure Mount Path is /data (standard Redis data directory)
Not /redis or other path
```

---

#### Issue 5: Web UI Not Accessible After Update

**Symptoms:**
- Container running but web UI won't load
- Connection refused or timeout
- Port not responding

**Diagnosis:**
```bash
# Check container is actually running
ssh waterbug.lan "docker ps | grep [appname]"

# Check ports
ssh waterbug.lan "docker port [container-name]"

# Check logs for startup errors
ssh waterbug.lan "docker logs [container-name] --tail 50"

# Test port locally on TrueNAS
ssh waterbug.lan "curl -I http://localhost:[port]"
```

**Solutions:**

**A. Container Not Fully Started**
```bash
# Wait 30-60 seconds for full startup
# Check logs for "ready" or "listening" messages
ssh waterbug.lan "docker logs [container-name] -f"
```

**B. Port Configuration Lost**
```
TrueNAS UI → Edit → Networking
Verify port mappings are still correct:
- syncthing: 8384, 22000, 21027
- calibre: 8080, 8081
- calibre-web: 8083
- vaultwarden: 80
- n8n: 5678
```

**C. Network Mode Changed**
```
Verify Network Mode in TrueNAS UI → Edit → Networking
Should match original (usually "bridge" or specific network)
```

---

#### Issue 6: App Shows Wrong/Old Data

**Symptoms:**
- App starts but shows old or incorrect data
- Mix of old and new data visible
- Data from wrong time period

**Diagnosis:**
```bash
# Check what's mounted
ssh waterbug.lan "docker inspect [container-name] --format '{{range .Mounts}}{{.Source}}{{println}}{{end}}'"

# Check last modified dates
ssh waterbug.lan "ls -lt /mnt/apps/apps/[appname]/config/ | head"
ssh waterbug.lan "ls -lt /mnt/.ix-apps/app_mounts/[appname]/config/ | head"

# Compare sizes
ssh waterbug.lan "du -sh /mnt/apps/apps/[appname]/"
ssh waterbug.lan "du -sh /mnt/.ix-apps/app_mounts/[appname]/"
```

**Solutions:**

**A. Accidentally Mounted Old Path**
```
Double-check TrueNAS UI → Edit → Storage
Ensure path is NEW location, not old
```

**B. Data Migration Incomplete**
```bash
# Re-run migration for specific app
ssh waterbug.lan

# Stop app
docker stop [container-name]

# Backup current new location
mv /mnt/apps/apps/[appname] /mnt/apps/apps/[appname].backup

# Re-copy from old location
mkdir -p /mnt/apps/apps/[appname]
cp -a /mnt/.ix-apps/app_mounts/[appname]/* /mnt/apps/apps/[appname]/
chown -R apps:apps /mnt/apps/apps/[appname]

# Restart app
docker start [container-name]
```

---

#### Issue 7: Spottarr Specific - Migration Timing

**Symptoms:**
- Spottarr data missing after update
- Error about missing configuration

**Diagnosis:**
```bash
# Check if data was migrated
ssh waterbug.lan "ls -la /mnt/apps/apps/spottarr/data/"

# Check if old location still has data
ssh waterbug.lan "ls -la /mnt/.ix-apps/app_mounts/spottarr/data/"
```

**Solutions:**

**A. Migration Skipped**
```bash
# Stop container
ssh waterbug.lan "docker stop dmz-spottarr"

# Migrate data now
ssh waterbug.lan "mkdir -p /mnt/apps/apps/spottarr"
ssh waterbug.lan "cp -a /mnt/.ix-apps/app_mounts/spottarr/data /mnt/apps/apps/spottarr/"
ssh waterbug.lan "chown -R apps:apps /mnt/apps/apps/spottarr"

# Update config in TrueNAS UI
# Start container
```

---

### Emergency Rollback Procedure

If an app is broken after update and needs immediate restoration:

#### Quick Rollback Steps

1. **Stop the app** (TrueNAS UI or `docker stop [container-name]`)

2. **Edit configuration**
   - TrueNAS UI → Apps → [appname] → Edit
   - Change Host Path BACK to old location:
     `/mnt/.ix-apps/app_mounts/[appname]/[directory]`
   - Save

3. **Start the app**
   - Should start with old configuration
   - Data at old location unchanged

4. **Investigate issue**
   - Don't proceed with other apps until issue understood
   - Check logs, permissions, paths
   - Consult troubleshooting section above

#### Full Rollback (All Apps)

If multiple apps are broken:

```bash
# For each app, update TrueNAS UI configuration back to:
# /mnt/.ix-apps/app_mounts/[appname]/...

# Old data is still intact at original locations
# No data loss should occur
```

#### Data Recovery

If data seems lost or corrupted:

```bash
# Check backup locations
ssh waterbug.lan "ls -la /mnt/.ix-apps/app_mounts/"

# Original data should still exist here
# Can re-migrate or restore as needed
```

---

### Getting Help

#### Log Collection for Support

```bash
# Collect comprehensive logs
ssh waterbug.lan << 'EOF'
mkdir -p /tmp/app-migration-logs
cd /tmp/app-migration-logs

# Container status
docker ps -a > container-status.txt

# All mounts
for container in $(docker ps -a --format '{{.Names}}' | grep -E 'syncthing|calibre|vaultwarden|n8n|spottarr'); do
  echo "=== $container ===" >> all-mounts.txt
  docker inspect "$container" --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}' >> all-mounts.txt 2>&1
  echo "" >> all-mounts.txt
done

# All logs
for container in $(docker ps -a --format '{{.Names}}' | grep -E 'syncthing|calibre|vaultwarden|n8n|spottarr'); do
  docker logs "$container" --tail 200 > "${container}.log" 2>&1
done

# Directory listings
ls -laR /mnt/apps/apps/ > new-location-listing.txt
ls -laR /mnt/.ix-apps/app_mounts/ > old-location-listing.txt

# Create tarball
tar czf /tmp/app-migration-logs.tar.gz .
EOF

# Download logs
scp waterbug.lan:/tmp/app-migration-logs.tar.gz ~/
```

#### Useful Commands for Debugging

```bash
# See all environment variables for a container
ssh waterbug.lan "docker inspect [container] --format '{{range .Config.Env}}{{println .}}{{end}}'"

# See full container configuration
ssh waterbug.lan "docker inspect [container] | less"

# Test database connectivity (postgres)
ssh waterbug.lan "docker exec [postgres-container] pg_isready"

# Check process inside container
ssh waterbug.lan "docker exec [container] ps aux"

# Check disk space
ssh waterbug.lan "df -h | grep -E 'apps|ix-apps'"
```

---

## Post-Update Validation

### Final System Check

After ALL apps updated successfully:

#### 1. All Containers Running
```bash
ssh waterbug.lan "docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E 'syncthing|calibre|vaultwarden|n8n|spottarr'"
```

Expected output:
```
ix-syncthing-syncthing-1         Up X minutes
ix-calibre-calibre-1             Up X minutes
ix-calibre-web-calibre-web-1     Up X minutes
ix-vaultwarden-vaultwarden-1     Up X minutes
ix-vaultwarden-postgres-1        Up X minutes
ix-n8n-n8n-1                     Up X minutes
ix-n8n-postgres-1                Up X minutes
ix-n8n-redis-1                   Up X minutes
dmz-spottarr                     Up X minutes
```

#### 2. No ix-apps Mounts
```bash
ssh waterbug.lan "docker inspect \$(docker ps -q) --format '{{.Name}}: {{range .Mounts}}{{.Source}}{{println}}{{end}}' | grep ix-apps"
```

Should return EMPTY (no results) - means no containers using old paths.

#### 3. All Apps Using New Paths
```bash
ssh waterbug.lan "docker inspect \$(docker ps -q) --format '{{.Name}}: {{range .Mounts}}{{.Source}}{{println}}{{end}}' | grep '/mnt/apps/apps/'"
```

Should show all app mounts at `/mnt/apps/apps/...`

#### 4. Web UI Accessibility

Test each app's web interface:
- [ ] Syncthing: http://waterbug.lan:8384
- [ ] Calibre: http://waterbug.lan:8080
- [ ] Calibre-Web: http://waterbug.lan:8083
- [ ] Vaultwarden: http://waterbug.lan (or configured domain)
- [ ] n8n: http://waterbug.lan:5678
- [ ] Spottarr: (check configured port)

#### 5. Functional Testing

**Syncthing:**
- [ ] Dashboard loads
- [ ] Folders visible
- [ ] Devices connected
- [ ] Sync working

**Calibre:**
- [ ] Desktop interface loads
- [ ] Library accessible
- [ ] Books visible

**Calibre-Web:**
- [ ] Web interface loads
- [ ] Library connected
- [ ] Books browsable
- [ ] Download works

**Vaultwarden:**
- [ ] Login successful
- [ ] Vault items visible
- [ ] Can create new item
- [ ] Browser extension connects
- [ ] Mobile app syncs

**n8n:**
- [ ] Login successful
- [ ] Workflows visible
- [ ] Can open workflow
- [ ] Can execute workflow
- [ ] Credentials accessible

**Spottarr:**
- [ ] Interface loads
- [ ] Configuration present

---

## Success Criteria

### Migration Complete When:

- ✅ All 9 apps showing "Running" status
- ✅ All apps using `/mnt/apps/apps/` paths
- ✅ No apps using `/mnt/.ix-apps/` paths
- ✅ All web UIs accessible
- ✅ All data visible and intact
- ✅ Core functionality tested for each app
- ✅ No errors in container logs
- ✅ All postgres databases accepting connections
- ✅ Redis (n8n) storing data correctly

### Optional Cleanup (After 1 Week of Stability)

Once ALL apps confirmed working for 1 week:

```bash
# Archive old ix-apps data (DON'T DELETE immediately)
ssh waterbug.lan "mkdir -p /mnt/apps/archives"
ssh waterbug.lan "mv /mnt/.ix-apps/app_mounts /mnt/apps/archives/app_mounts.backup.$(date +%Y%m%d)"

# After another week, if everything still works, can delete:
ssh waterbug.lan "rm -rf /mnt/apps/archives/app_mounts.backup.*"
```

**IMPORTANT:** Do NOT delete old data until absolutely certain everything works.

---

## Document Revision History

| Date | Version | Changes |
|------|---------|---------|
| 2025-12-30 | 1.0 | Initial comprehensive guide created |

---

## Quick Reference Card

### Path Translation Table

| App | Old Path | New Path |
|-----|----------|----------|
| syncthing | /mnt/.ix-apps/app_mounts/syncthing/config | /mnt/apps/apps/syncthing/config |
| calibre | /mnt/.ix-apps/app_mounts/calibre/config | /mnt/apps/apps/calibre/config |
| calibre-web | /mnt/.ix-apps/app_mounts/calibre-web/config | /mnt/apps/apps/calibre-web/config |
| vaultwarden | /mnt/.ix-apps/app_mounts/vaultwarden/data | /mnt/apps/apps/vaultwarden/data |
| vaultwarden-postgres | /mnt/.ix-apps/app_mounts/vaultwarden/postgres_data | /mnt/apps/apps/vaultwarden/postgres |
| n8n | /mnt/.ix-apps/app_mounts/n8n/data | /mnt/apps/apps/n8n/data |
| n8n-postgres | /mnt/.ix-apps/app_mounts/n8n/postgres_data | /mnt/apps/apps/n8n/postgres |
| n8n-redis | Docker Volume (ix-n8n_redis) | /mnt/apps/apps/n8n/redis |
| spottarr | /mnt/.ix-apps/app_mounts/spottarr/data | /mnt/apps/apps/spottarr/data |

### Container Names Reference

| App | Container Name | Notes |
|-----|---------------|-------|
| syncthing | ix-syncthing-syncthing-1 | Single container |
| calibre | ix-calibre-calibre-1 | Single container |
| calibre-web | ix-calibre-web-calibre-web-1 | Single container |
| vaultwarden | ix-vaultwarden-vaultwarden-1 | Main app |
| vaultwarden-postgres | ix-vaultwarden-postgres-1 | Database |
| n8n | ix-n8n-n8n-1 | Main app |
| n8n-postgres | ix-n8n-postgres-1 | Database |
| n8n-redis | ix-n8n-redis-1 | Cache |
| spottarr | dmz-spottarr | Different naming |

---

**END OF GUIDE**
