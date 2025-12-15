---
phase: 15-self-managing-infrastructure
plan: 15-03a
title: Chezmoi Sync Module with Jujutsu
depends_on:
  - Phase 4 (SOPS secrets with SSH keys)
status: not_started
---

# Plan 15-03a: Chezmoi Sync Module with Jujutsu

## Objective

Create a bulletproof chezmoi synchronization module using Jujutsu (jj) for conflict-free multi-host dotfile management. This module enables multiple hosts to independently commit dotfile changes without clobbering each other or blocking on merge conflicts.

**Key Innovation**: jj's conflict-free merge model turns concurrent edits into parallel commits instead of blocking failures. No manual conflict resolution needed, no lost work, fully automated.

## Success Criteria

- [ ] Module `modules/services/dotfiles/chezmoi-sync.nix` created with full options
- [ ] Sync script uses jj commands for fetch, rebase, commit, push
- [ ] Conflicts automatically handled by jj (parallel commits, no blocking)
- [ ] Manual commands available: `chezmoi-sync`, `chezmoi-status`, `chezmoi-show-conflicts`
- [ ] State tracking in `/var/lib/chezmoi-sync/last-sync-status`
- [ ] Graceful handling of network failures (don't break workflow)
- [ ] jj co-located repository automatically initialized if needed

## Context

**Why jj Instead of Git**:
- **No manual conflict resolution**: jj creates new commits for both sides of conflicts
- **No lost work**: All changes preserved as separate commits in history
- **Simpler automation**: No complex merge/rebase/conflict handling code needed
- **Offline-first**: Local operations work without network
- **Resume-friendly**: Failed pushes tracked, resume automatically next sync

**Architecture**:
```
Each Host:
  ~/.local/share/chezmoi (jj co-located repo)
       ↓
  jj git fetch (from GitHub)
       ↓
  jj rebase (automatic conflict resolution)
       ↓
  chezmoi re-add (capture dotfile changes)
       ↓
  jj describe (update commit message)
       ↓
  jj git push (to GitHub)
```

## Implementation Tasks

### Task 1: Create Chezmoi Sync Module

**File**: `modules/services/dotfiles/chezmoi-sync.nix`

**Module Structure**:
```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.myModules.services.dotfiles.chezmoiSync;

  # Sync script using jj commands
  syncScript = pkgs.writeShellScript "chezmoi-sync" ''
    set -euo pipefail

    CHEZMOI_DIR="$HOME/.local/share/chezmoi"
    STATE_DIR="/var/lib/chezmoi-sync"
    STATE_FILE="$STATE_DIR/last-sync-status"
    HOSTNAME=$(hostname)

    mkdir -p "$STATE_DIR"

    log() {
      echo "[chezmoi-sync] $*"
      logger -t chezmoi-sync "$*"
    }

    cd "$CHEZMOI_DIR"

    # Ensure jj is initialized (co-located with git)
    if [ ! -d .jj ]; then
      log "Initializing jj co-located repo..."
      ${pkgs.jujutsu}/bin/jj git init --colocate
    fi

    # Step 1: Fetch remote changes via jj
    log "Fetching remote changes..."
    if ! ${pkgs.jujutsu}/bin/jj git fetch; then
      log "Warning: Could not fetch (no network?)"
      echo "fetch-failed" > "$STATE_FILE"
      exit 0  # Don't fail, just skip sync
    fi

    # Step 2: Rebase working copy on latest remote
    log "Rebasing working copy on remote changes..."
    # jj automatically handles conflicts by creating separate commits
    ${pkgs.jujutsu}/bin/jj rebase -d @- -s @

    # Check if conflicts exist (for logging)
    if ${pkgs.jujutsu}/bin/jj log --conflicts -r @ &>/dev/null; then
      CONFLICTS=$(${pkgs.jujutsu}/bin/jj log --conflicts -r @ --no-graph -T 'change_id' | wc -l)
      if [ "$CONFLICTS" -gt 0 ]; then
        log "Note: $CONFLICTS conflict(s) detected - preserved as separate commits"
        echo "conflicts-preserved" > "$STATE_FILE"
      fi
    fi

    # Step 3: Capture current dotfiles state
    log "Capturing current dotfiles with chezmoi re-add..."
    ${pkgs.chezmoi}/bin/chezmoi re-add

    # Step 4: Update working copy description (commit message)
    log "Updating commit description..."
    ${pkgs.jujutsu}/bin/jj describe -m "chore($HOSTNAME): sync dotfiles - $(date -Iseconds)"

    # Step 5: Push to git remote
    log "Pushing to git remote..."
    if ${pkgs.jujutsu}/bin/jj git push; then
      log "Successfully pushed changes"
      echo "success" > "$STATE_FILE"
    else
      log "Warning: Could not push (no network?)"
      echo "push-failed" > "$STATE_FILE"
      # Don't fail - changes are committed locally
      # jj will push on next successful sync
      exit 0
    fi

    log "Chezmoi sync complete"
  '';

  # Manual status command
  statusCmd = pkgs.writeShellScriptBin "chezmoi-status" ''
    CHEZMOI_DIR="$HOME/.local/share/chezmoi"
    STATE_FILE="/var/lib/chezmoi-sync/last-sync-status"

    echo "=== Chezmoi Sync Status ==="
    echo ""

    # Show last sync status
    if [ -f "$STATE_FILE" ]; then
      STATUS=$(cat "$STATE_FILE")
      echo "Last sync: $STATUS"
    else
      echo "Last sync: Never"
    fi

    echo ""

    # Show jj status
    if [ -d "$CHEZMOI_DIR/.jj" ]; then
      cd "$CHEZMOI_DIR"
      echo "=== jj Working Copy Status ==="
      ${pkgs.jujutsu}/bin/jj status
      echo ""
      echo "=== Recent jj Log ==="
      ${pkgs.jujutsu}/bin/jj log --limit 5
    else
      echo "jj not initialized in chezmoi directory"
    fi
  '';

  # Manual conflict checker
  showConflictsCmd = pkgs.writeShellScriptBin "chezmoi-show-conflicts" ''
    CHEZMOI_DIR="$HOME/.local/share/chezmoi"

    if [ ! -d "$CHEZMOI_DIR/.jj" ]; then
      echo "Error: jj not initialized in chezmoi directory"
      exit 1
    fi

    cd "$CHEZMOI_DIR"

    echo "=== Checking for conflicts in jj log ==="
    if ${pkgs.jujutsu}/bin/jj log --conflicts; then
      echo ""
      echo "Conflicts found. To resolve:"
      echo "  1. cd ~/.local/share/chezmoi"
      echo "  2. jj resolve (interactive resolution)"
      echo "  3. jj describe -m \"fix: reconcile conflicts\""
      echo "  4. jj git push"
    else
      echo "No conflicts found!"
    fi
  '';

  # Manual sync command (wrapper)
  syncCmd = pkgs.writeShellScriptBin "chezmoi-sync" ''
    sudo systemctl start chezmoi-sync-manual.service
    journalctl -u chezmoi-sync-manual.service -f
  '';
in
{
  options.myModules.services.dotfiles.chezmoiSync = {
    enable = lib.mkEnableOption "automatic chezmoi repository synchronization";

    repoUrl = lib.mkOption {
      type = lib.types.str;
      example = "git@github.com:user/dotfiles.git";
      description = ''
        Git URL for chezmoi dotfiles repository.
        jj uses git as a backend for remote operations.
      '';
    };

    syncBeforeUpdate = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Automatically sync chezmoi before OS updates.
        Creates chezmoi-pre-update.service that runs before auto-upgrade.
      '';
    };

    autoCommit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Automatically commit local changes with hostname and timestamp.
        Commits use format: "chore(hostname): sync dotfiles - timestamp"
      '';
    };

    autoPush = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Automatically push commits to remote.
        Fails gracefully if no network - changes remain local until next sync.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Install required packages
    environment.systemPackages = [
      pkgs.jujutsu  # Required for conflict-free sync
      pkgs.chezmoi  # Dotfile manager
      statusCmd
      showConflictsCmd
      syncCmd
    ];

    # Pre-update service (runs before auto-upgrade if enabled)
    systemd.services.chezmoi-pre-update = lib.mkIf cfg.syncBeforeUpdate {
      description = "Sync chezmoi dotfiles before OS update";
      documentation = [ "Captures local dotfile changes and syncs with remote" ];

      # Run before auto-upgrade (if it exists)
      before = lib.optional config.myModules.services.system.autoUpgrade.enable "auto-upgrade.service";

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${syncScript}";
        # Run as the primary user (not root)
        User = config.users.users.rain.name;  # TODO: Make this configurable
        Environment = "HOME=${config.users.users.rain.home}";
      };
    };

    # Manual sync service (for testing/debugging)
    systemd.services.chezmoi-sync-manual = {
      description = "Manual chezmoi sync (for testing)";

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${syncScript}";
        User = config.users.users.rain.name;
        Environment = "HOME=${config.users.users.rain.home}";
      };
    };

    # State directory
    systemd.tmpfiles.rules = [
      "d /var/lib/chezmoi-sync 0755 root root -"
    ];
  };
}
```

**Key Design Decisions**:
1. **jj co-located repo**: Automatically initialized on first run if not present
2. **Graceful degradation**: Network failures don't break workflow, just skip sync
3. **State tracking**: Last sync status in `/var/lib/chezmoi-sync/last-sync-status`
4. **Conflict handling**: jj does it automatically, just log for user awareness
5. **User context**: Service runs as user (not root) to access ~/.local/share/chezmoi

### Task 2: Create Module Directory Structure

**Files to create**:
```bash
mkdir -p modules/services/dotfiles
touch modules/services/dotfiles/default.nix
touch modules/services/dotfiles/chezmoi-sync.nix
```

**`modules/services/dotfiles/default.nix`**:
```nix
{ ... }:
{
  imports = [
    ./chezmoi-sync.nix
  ];
}
```

**Update `modules/services/default.nix`** to import dotfiles:
```nix
{ ... }:
{
  imports = [
    ./networking
    ./dotfiles  # NEW
  ];
}
```

### Task 3: Enable in Desktop/Laptop Roles

**File**: `roles/form-desktop.nix`

Add after SSH/Tailscale configuration:
```nix
# CHEZMOI DOTFILE SYNC
myModules.services.dotfiles.chezmoiSync = {
  enable = lib.mkDefault true;
  repoUrl = lib.mkDefault "git@github.com:rain/dotfiles.git";  # User must override
  syncBeforeUpdate = lib.mkDefault true;
  autoCommit = lib.mkDefault true;
  autoPush = lib.mkDefault true;
};
```

**File**: `roles/form-laptop.nix` (same config)

**File**: `roles/form-server.nix` and `roles/form-pi.nix` (same config, but user might disable)

## Testing

### Test 1: Build Verification

```bash
# Build all affected hosts
nh os build

# Expected: No errors, jujutsu package available
```

### Test 2: Manual Sync Test

```bash
# On malphas (desktop)
# 1. Initialize chezmoi with jj (if not already done)
cd ~/.local/share/chezmoi
jj git init --colocate
jj log

# 2. Test manual sync
chezmoi-sync

# 3. Verify state
chezmoi-status
cat /var/lib/chezmoi-sync/last-sync-status

# Expected: "success" or graceful failure with clear message
```

### Test 3: Conflict Simulation

```bash
# On malphas
cd ~/.local/share/chezmoi
echo "# Malphas change $(date)" >> dot_bashrc
jj describe -m "test: malphas bashrc change"
jj git push

# On griefling (same time)
cd ~/.local/share/chezmoi
echo "# Griefling change $(date)" >> dot_bashrc
chezmoi-sync  # Will fetch malphas's change and rebase

# Verify both changes preserved
jj log --limit 5
# Expected: TWO commits visible, no conflict errors
```

### Test 4: Network Failure Handling

```bash
# On griefling VM
sudo systemctl stop NetworkManager
chezmoi-sync

# Expected: Graceful "Warning: Could not fetch" message
# State file: "fetch-failed"
# Script exits 0 (success, not failure)

sudo systemctl start NetworkManager
```

## Documentation

Add to module file header:
```nix
# Chezmoi Sync Module
#
# Automatically synchronizes chezmoi dotfiles repository using Jujutsu (jj)
# for conflict-free multi-host management.
#
# Features:
# - Conflict-free sync using jj (concurrent edits become parallel commits)
# - Automatic sync before OS updates (captures local changes)
# - Graceful network failure handling (offline-friendly)
# - Manual commands: chezmoi-sync, chezmoi-status, chezmoi-show-conflicts
# - State tracking for debugging
#
# Workflow:
#   jj git fetch → jj rebase → chezmoi re-add → jj describe → jj git push
#
# Why jj:
# - No manual conflict resolution needed
# - All changes preserved as separate commits
# - Simpler automation (no complex merge logic)
# - Offline-first design
```

## Known Issues / Future Improvements

1. **User hardcoded**: Currently hardcodes `rain` user, should be configurable
2. **Multi-user**: Only supports single-user systems, needs per-user service
3. **Repo URL**: User must override repoUrl in host config, could auto-detect
4. **Conflict notification**: Should optionally notify user about conflicts
5. **Retry logic**: Failed pushes don't retry automatically (wait for next sync)

## Dependencies

- Phase 4: SOPS with SSH keys (for git push authentication)
- Chezmoi installed (already in desktop/laptop roles)
- jujutsu package available in nixpkgs
- User must have chezmoi repo initialized

## Security Considerations

1. **SSH keys**: Already deployed via SOPS (Phase 4)
2. **Repo access**: Only authorized hosts have push access via SSH key
3. **State files**: Stored in `/var/lib/` with root-only write access
4. **User context**: Service runs as user to access home directory safely
5. **No secrets in commits**: Module doesn't handle secrets (use SOPS)

## Rollback Plan

If sync causes issues:

1. **Disable module**: Set `myModules.services.dotfiles.chezmoiSync.enable = false;`
2. **Remove hook**: Will be handled in 15-03b when integrating with auto-upgrade
3. **Reset jj state**:
   ```bash
   cd ~/.local/share/chezmoi
   jj git fetch
   jj rebase -d @- -s @
   jj status
   ```
4. **Nuclear option**: Remove `.jj/`, re-init with `jj git init --colocate`

## Success Metrics

- [ ] Module builds without errors
- [ ] Manual sync works on desktop
- [ ] Conflicts handled automatically (parallel commits)
- [ ] Network failures graceful (no service failures)
- [ ] State file tracks sync status correctly
- [ ] Manual commands provide useful debugging info

## Next Steps

After this plan completes:
- **15-03b**: Integrate with auto-upgrade module (preUpdateHooks)
- **15-03c**: Secret migration and comprehensive testing
