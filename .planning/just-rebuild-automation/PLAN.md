# Just Automation for Seamless NixOS Rebuilds

**Objective**: Create a single `just rebuild-smart` command that intelligently handles upstream sync, local changes, chezmoi dotfiles, auto-updates, and NixOS rebuilding in one seamless workflow.

**Status**: Planning
**Estimated Effort**: 3-4 hours
**Risk Level**: Low (builds on existing proven infrastructure)

---

## Context

Currently, the workflow for rebuilding NixOS on any host requires multiple manual steps:
1. Pull upstream changes from nix-config
2. Trigger chezmoi re-add to capture dotfile changes
3. Handle potential conflicts
4. Run auto-updates (flake update, etc.)
5. Execute `nh os switch -u`

**Goal**: Reduce this to one command: `just rebuild-smart`

---

## Existing Infrastructure to Recycle

### 1. Chezmoi Sync Module (`modules/services/dotfiles/chezmoi-sync.nix`)

**Already implements**:
- ✅ Jujutsu-based conflict-free sync
- ✅ Automatic `chezmoi re-add` to capture local changes
- ✅ Git fetch → jj rebase → describe → push workflow
- ✅ Graceful network failure handling
- ✅ State tracking (`/var/lib/chezmoi-sync/last-sync-status`)
- ✅ Manual commands: `chezmoi-sync`, `chezmoi-status`, `chezmoi-show-conflicts`

**What we can reuse**:
- The sync script logic (lines 39-123)
- Conflict handling via jj (automatic parallel commits)
- Network-aware operations (offline-friendly)
- Pre-update hook mechanism (line 250-265)

### 2. Justfile Rebuild Recipes

**Existing recipes** (lines 19-52):
- `rebuild-pre`: Updates nix-secrets, adds intent-to-add
- `rebuild`: Calls `scripts/rebuild.sh`
- `rebuild-post`: Checks sops
- `rebuild-update`: Flake update + rebuild
- `update-nix-secrets`: Pulls nix-secrets and updates flake input

**What we can reuse**:
- Pre/post hooks pattern
- Nix-secrets update logic
- SOPS validation
- Git intent-to-add pattern

### 3. VCS Helpers (`scripts/vcs-helpers.sh`)

**Functions available**:
- `vcs_pull`: Smart pull with conflict detection
- `vcs_add`: Stage files
- `vcs_commit`: Create commits
- `vcs_push`: Push changes
- Git/Jujutsu abstraction layer

**What we can reuse**:
- Conflict-free pull logic
- Automatic commit generation
- Network failure handling

---

## Design: Smart Rebuild Command

### Command Signature

```bash
just rebuild-smart [OPTIONS]
```

**Options:**
- `--skip-upstream`: Don't pull from remote
- `--skip-dotfiles`: Don't sync chezmoi
- `--skip-update`: Don't run flake update
- `--dry-run`: Show what would be done without executing

**Default behavior** (no flags):
1. Pull upstream nix-config changes
2. Sync chezmoi dotfiles (capture local changes)
3. Merge local+upstream using jj (conflict-free)
4. Update nix-secrets
5. Run `flake update` (optional, controlled by flag)
6. Execute `nh os switch -u`
7. Run post-rebuild checks

---

## Workflow Phases

### Phase 1: Pre-Sync Preparation (2 minutes)

**Goal**: Ensure repo is in clean state, check prerequisites

**Steps**:
1. Check if we're in nix-config directory
2. Verify git/jj status (warn if uncommitted changes)
3. Record current commit hash (for rollback)
4. Check network connectivity (determines online/offline mode)

**Script location**: `scripts/rebuild-smart-pre.sh`

### Phase 2: Upstream Sync (3 minutes)

**Goal**: Pull latest changes from remote without conflicts

**Steps**:
1. Fetch upstream changes (`jj git fetch` or `git fetch`)
2. Rebase local changes on top of upstream (`jj rebase`)
3. If using git: attempt automatic merge, fallback to jj if conflicts
4. Preserve all local commits as parallel branches (jj advantage)

**Script location**: `scripts/rebuild-smart-sync.sh`

**Recycled from**:
- `chezmoi-sync.nix` lines 70-89 (jj fetch + rebase logic)
- `vcs-helpers.sh` `vcs_pull` function

### Phase 3: Dotfiles Sync (2 minutes)

**Goal**: Capture any local dotfile changes and sync with remote

**Steps**:
1. Check if chezmoi is initialized (`~/.local/share/chezmoi`)
2. Run chezmoi sync service (`systemctl start chezmoi-sync-manual.service`)
3. Wait for completion and check status
4. If conflicts: preserve as separate commits (jj handles automatically)
5. Push dotfiles changes to remote

**Script location**: `scripts/rebuild-smart-dotfiles.sh`

**Recycled from**:
- `chezmoi-sync.nix` entire sync script (lines 39-123)
- Already proven to work via systemd service

### Phase 4: Nix-Secrets Update (1 minute)

**Goal**: Pull latest secrets from nix-secrets repo

**Steps**:
1. Pull nix-secrets repo (if it exists)
2. Update flake input `nix flake update nix-secrets --timeout 5`
3. Verify secrets are accessible (optional)

**Script location**: Reuse existing `update-nix-secrets` recipe

**Recycled from**:
- `justfile` lines 66-68 (already working)

### Phase 5: Flake Update (Optional, 1-3 minutes)

**Goal**: Update flake inputs to latest versions

**Steps**:
1. Run `nix flake update` (if `--update` flag passed)
2. Stage flake.lock changes
3. Commit with descriptive message

**Script location**: Reuse existing `update` recipe

**Recycled from**:
- `justfile` line 47-48 (already working)

### Phase 6: NixOS Rebuild (5-15 minutes)

**Goal**: Apply all changes to system

**Steps**:
1. Add all changes with intent-to-add (`git add --intent-to-add .`)
2. Run `nh os switch -u` (or `scripts/rebuild.sh` for compatibility)
3. Capture rebuild output for error handling
4. If failure: offer rollback option

**Script location**: Reuse `scripts/rebuild.sh`

**Recycled from**:
- `justfile` line 34 (rebuild recipe)
- `scripts/rebuild.sh` (existing script)

### Phase 7: Post-Rebuild Checks (1 minute)

**Goal**: Verify system health after rebuild

**Steps**:
1. Check if sops-nix activated (`scripts/check-sops.sh`)
2. Verify systemd services started correctly
3. Check for failed units (`systemctl --failed`)
4. Display summary of changes applied

**Script location**: Expand `scripts/check-sops.sh`

**Recycled from**:
- `justfile` line 24 (rebuild-post)
- `scripts/check-sops.sh` (existing)

### Phase 8: Commit & Push (Optional, 1 minute)

**Goal**: Save rebuild state to remote

**Steps**:
1. Commit any staged changes (if auto-commit enabled)
2. Push to remote (if network available)
3. Tag successful builds (optional)

**Script location**: `scripts/rebuild-smart-commit.sh`

**Recycled from**:
- `vcs-helpers.sh` `vcs_commit` and `vcs_push`
- `chezmoi-sync.nix` auto-commit logic (lines 92-116)

---

## Implementation Plan

### Task 1: Create Main Orchestrator Script (1 hour)

**File**: `scripts/rebuild-smart.sh`

```bash
#!/usr/bin/env bash
# Main orchestrator for smart rebuild workflow

set -euo pipefail

# Parse command-line flags
SKIP_UPSTREAM=false
SKIP_DOTFILES=false
SKIP_UPDATE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-upstream) SKIP_UPSTREAM=true ;;
    --skip-dotfiles) SKIP_DOTFILES=true ;;
    --skip-update) SKIP_UPDATE=true ;;
    --dry-run) DRY_RUN=true ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vcs-helpers.sh"
source "$SCRIPT_DIR/rebuild-smart-helpers.sh"

# Phase 1: Preparation
phase "Preparation" rebuild_smart_prepare

# Phase 2: Upstream Sync (unless skipped)
if ! $SKIP_UPSTREAM; then
  phase "Upstream Sync" rebuild_smart_sync_upstream
fi

# Phase 3: Dotfiles Sync (unless skipped)
if ! $SKIP_DOTFILES; then
  phase "Dotfiles Sync" rebuild_smart_sync_dotfiles
fi

# Phase 4: Nix-Secrets Update
phase "Nix-Secrets Update" rebuild_smart_update_secrets

# Phase 5: Flake Update (unless skipped)
if ! $SKIP_UPDATE; then
  phase "Flake Update" rebuild_smart_flake_update
fi

# Phase 6: NixOS Rebuild
phase "NixOS Rebuild" rebuild_smart_nixos_rebuild

# Phase 7: Post-Rebuild Checks
phase "Post-Rebuild Checks" rebuild_smart_post_checks

# Phase 8: Commit & Push (auto-commit enabled)
phase "Commit & Push" rebuild_smart_commit_push

echo "✅ Smart rebuild complete!"
```

**Dependencies**:
- Helper scripts for each phase
- `vcs-helpers.sh` (already exists)
- Color/formatting helpers

### Task 2: Create Helper Functions (1 hour)

**File**: `scripts/rebuild-smart-helpers.sh`

**Functions to implement**:
```bash
rebuild_smart_prepare() {
  # Check prerequisites
  # Verify git/jj status
  # Record current state
}

rebuild_smart_sync_upstream() {
  # Fetch + rebase upstream changes
  # Handle conflicts with jj
}

rebuild_smart_sync_dotfiles() {
  # Call chezmoi-sync
  # Wait for completion
}

rebuild_smart_update_secrets() {
  # Call existing update-nix-secrets logic
}

rebuild_smart_flake_update() {
  # Run nix flake update
  # Stage and commit flake.lock
}

rebuild_smart_nixos_rebuild() {
  # Call nh os switch -u
  # Capture and display output
}

rebuild_smart_post_checks() {
  # Run check-sops
  # Check systemd status
}

rebuild_smart_commit_push() {
  # Auto-commit if enabled
  # Push to remote
}
```

**Recycles**:
- Existing chezmoi-sync script (90% reusable)
- VCS helpers (100% reusable)
- Check-sops (100% reusable)

### Task 3: Add Justfile Recipe (15 minutes)

**File**: `justfile` (add after existing rebuild recipes)

```just
# Smart rebuild: sync upstream + dotfiles + rebuild in one command
rebuild-smart *FLAGS:
  #!/usr/bin/env bash
  set -euo pipefail
  scripts/rebuild-smart.sh {{FLAGS}}

# Smart rebuild with flake update
rebuild-smart-update: (rebuild-smart "--update")

# Offline rebuild (skip upstream/dotfiles sync)
rebuild-smart-offline: (rebuild-smart "--skip-upstream --skip-dotfiles")

# Dry run to see what would be done
rebuild-smart-dry: (rebuild-smart "--dry-run")
```

**Integrates with**:
- Existing `rebuild` recipes (backwards compatible)
- VM workflow (`vm-rebuild` can call this)
- Manual workflow (users can still use old commands)

### Task 4: Integrate Chezmoi Sync (30 minutes)

**File**: Modify `modules/services/dotfiles/chezmoi-sync.nix`

**Changes**:
1. Extract sync script to standalone executable
2. Add return codes for script exit status
3. Add `--wait` flag for synchronous operation
4. Make it callable from justfile directly

**New function**:
```nix
# Standalone sync command (can be called outside systemd)
syncCmdDirect = pkgs.writeShellScriptBin "chezmoi-sync-direct" ''
  ${syncScript}
  # Exit with proper status code
  STATE_FILE="/var/lib/chezmoi-sync/last-sync-status"
  if [ -f "$STATE_FILE" ]; then
    STATUS=$(cat "$STATE_FILE")
    case "$STATUS" in
      success*) exit 0 ;;
      *) exit 1 ;;
    esac
  fi
  exit 0
'';
```

**Why**:
- Can be called synchronously from just
- Proper error propagation
- No systemd dependency for manual runs

### Task 5: Add Conflict Resolution Helpers (30 minutes)

**File**: `scripts/rebuild-smart-conflict-helpers.sh`

**Functions**:
```bash
check_for_conflicts() {
  # Check jj log for conflicts
  # Return 0 if clean, 1 if conflicts exist
}

show_conflict_summary() {
  # Display which files have conflicts
  # Offer resolution options
}

auto_resolve_conflicts() {
  # Attempt automatic resolution for simple cases
  # Preserve both versions as separate commits
}
```

**Recycles**:
- `chezmoi-show-conflicts` command logic
- jj conflict detection (already in chezmoi-sync)

### Task 6: Add Progress Indicators (30 minutes)

**File**: `scripts/rebuild-smart-ui.sh`

**Features**:
- Spinners for long-running operations
- Progress bars for multi-step phases
- Color-coded status messages
- Summary table at end

**Example output**:
```
🚀 Smart NixOS Rebuild
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[✓] Phase 1: Preparation (2s)
[✓] Phase 2: Upstream Sync (5s)
[✓] Phase 3: Dotfiles Sync (3s)
[✓] Phase 4: Nix-Secrets Update (1s)
[⏭] Phase 5: Flake Update (skipped)
[⏳] Phase 6: NixOS Rebuild (in progress...)
```

**Libraries**:
- Use bash built-ins (no external deps)
- ANSI escape codes for colors
- Simple progress tracking

---

## Configuration Options

### Add to Host Configuration

**File**: `modules/common/default.nix` (or host-specific)

```nix
myModules.services.rebuild.smart = {
  enable = true;
  autoCommit = true;  # Auto-commit after successful rebuild
  autoPush = true;    # Auto-push to remote
  updateBeforeRebuild = false;  # Run flake update by default
  syncDotfiles = true;  # Always sync dotfiles
  offlineMode = false;  # Skip network operations
};
```

**Why**:
- Per-host customization
- Different behavior for servers vs desktops
- Easy to disable features

---

## Error Handling & Rollback

### Automatic Rollback on Failure

**Scenario 1**: Upstream sync fails
- **Action**: Continue with local state only
- **Warning**: Display that running on stale upstream

**Scenario 2**: Dotfiles sync fails
- **Action**: Continue without dotfile changes
- **Warning**: Dotfiles may be out of sync

**Scenario 3**: NixOS rebuild fails
- **Action**: Offer rollback to previous generation
- **Command**: `sudo nixos-rebuild switch --rollback`

**Scenario 4**: Network failure
- **Action**: Enter offline mode automatically
- **Skip**: Upstream sync, dotfiles push, nix-secrets update

### Manual Rollback

```bash
just rebuild-smart-rollback
```

**Implementation**:
```bash
# Saved state before rebuild
PREV_COMMIT=$(git rev-parse HEAD)

# On failure:
git reset --hard "$PREV_COMMIT"
sudo nixos-rebuild switch --rollback
```

---

## Testing Strategy

### Phase 1: Unit Tests (30 minutes)

Test each phase independently:

```bash
# Test upstream sync
just test-rebuild-smart-sync

# Test dotfiles sync
just test-rebuild-smart-dotfiles

# Test with conflicts
just test-rebuild-smart-conflicts
```

### Phase 2: Integration Tests (1 hour)

Test full workflow in VM:

```bash
# Fresh VM install
just vm-fresh griefling

# Make local changes
just vm-ssh griefling
# Edit some files...

# Run smart rebuild
just vm-rebuild-smart griefling

# Verify changes applied
```

### Phase 3: Real-World Testing (1 hour)

Test on actual host:

```bash
# Dry run first
just rebuild-smart-dry

# Offline mode (no network)
just rebuild-smart-offline

# Full rebuild
just rebuild-smart

# With updates
just rebuild-smart-update
```

---

## Success Criteria

- [ ] Single command rebuilds NixOS with all syncs
- [ ] Handles upstream changes without conflicts
- [ ] Captures local dotfile changes automatically
- [ ] Works offline (graceful degradation)
- [ ] Provides clear progress indicators
- [ ] Auto-commits successful builds (configurable)
- [ ] Rolls back on failures
- [ ] Backwards compatible with existing `just rebuild`
- [ ] Works in VM testing workflow
- [ ] Tested on at least 2 different hosts

---

## Migration Path

### For Existing Users

**Current command**:
```bash
just rebuild
```

**New command**:
```bash
just rebuild-smart
```

**Backwards compatibility**:
- Keep `just rebuild` working as-is
- Add `just rebuild-smart` as new option
- Gradually migrate users
- Eventually make `rebuild` an alias to `rebuild-smart`

### For New Hosts

**Recommend `rebuild-smart` as default**:
```bash
# In host configuration
myModules.services.rebuild.smart.enable = true;

# Alias for convenience
programs.bash.shellAliases.rebuild = "just rebuild-smart";
```

---

## Future Enhancements

### Phase 2 Features (Post-Implementation)

1. **Smart Update Detection**
   - Only run `flake update` if inputs are stale (>7 days)
   - Show changelog of updated inputs

2. **Parallel Operations**
   - Sync dotfiles while pulling upstream
   - Download packages while building config

3. **Rollback History**
   - Track last N successful builds
   - Quick rollback to any previous state

4. **Rebuild Hooks**
   - Pre-rebuild user scripts
   - Post-rebuild notifications
   - Slack/Discord webhook on success/failure

5. **Interactive Mode**
   - Ask before each phase
   - Show diffs before applying
   - Manual conflict resolution

---

## Timeline

| Task | Estimated Time | Dependencies |
|------|----------------|--------------|
| Task 1: Main Orchestrator | 1 hour | None |
| Task 2: Helper Functions | 1 hour | Task 1 |
| Task 3: Justfile Recipe | 15 min | Task 1 |
| Task 4: Chezmoi Integration | 30 min | Task 2 |
| Task 5: Conflict Helpers | 30 min | Task 2 |
| Task 6: Progress UI | 30 min | Task 1 |
| Testing | 2 hours | All tasks |
| **Total** | **5.5 hours** | |

**Realistic estimate**: 6-8 hours with testing and refinement

---

## Next Steps

1. Review this plan for completeness
2. Approve approach and design decisions
3. Start with Task 1: Main Orchestrator
4. Incrementally build and test each phase
5. Deploy to test VM (griefling)
6. Deploy to personal host
7. Document usage in README

---

## Open Questions

1. **Should we make this the default `just rebuild`?**
   - Pro: One less thing to remember
   - Con: Breaks existing muscle memory
   - **Recommendation**: Keep both, gradually migrate

2. **Auto-commit on successful rebuilds?**
   - Pro: Never lose working configurations
   - Con: Lots of "chore: rebuild" commits
   - **Recommendation**: Make it configurable, default ON

3. **Handle multi-user systems?**
   - Current design assumes single primary user
   - **Recommendation**: Phase 2 feature

4. **Integration with GitHub Actions?**
   - Could auto-rebuild on push
   - **Recommendation**: Phase 2 feature

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Conflicts during merge | Medium | Low | jj handles automatically |
| Network failures | High | Low | Graceful offline mode |
| Rebuild failures | Low | High | Automatic rollback |
| Breaking existing workflow | Low | Medium | Keep old commands working |
| Complexity creep | Medium | Medium | Start simple, add features gradually |

---

## Documentation Requirements

### User-Facing Docs

1. **Quick Start Guide**
   ```bash
   # Simple rebuild
   just rebuild-smart

   # With updates
   just rebuild-smart --update

   # Offline mode
   just rebuild-smart --skip-upstream --skip-dotfiles
   ```

2. **Troubleshooting Guide**
   - What to do if sync fails
   - How to resolve conflicts
   - Manual rollback procedure

3. **Configuration Reference**
   - All available options
   - Per-host customization
   - Examples

### Developer Docs

1. **Architecture Overview**
   - Phase breakdown
   - Data flow diagram
   - Error handling flow

2. **Adding New Phases**
   - How to extend the workflow
   - Hook points for custom scripts

3. **Testing Guide**
   - How to run unit tests
   - VM testing procedure

---

## Summary

This plan creates a **single-command NixOS rebuild workflow** that:

✅ Syncs upstream changes (jj-based, conflict-free)
✅ Captures local dotfile changes (chezmoi re-add)
✅ Updates nix-secrets
✅ Optionally updates flake inputs
✅ Rebuilds NixOS with `nh os switch -u`
✅ Works offline (graceful degradation)
✅ Auto-commits successful builds
✅ Rolls back on failure

**Recycles existing proven infrastructure**:
- 90% of chezmoi-sync.nix
- 100% of vcs-helpers.sh
- 100% of existing rebuild recipes
- All existing check scripts

**Implementation effort**: 6-8 hours
**Maintenance cost**: Low (builds on stable components)
**User benefit**: Massive (from 6 steps to 1 command)
