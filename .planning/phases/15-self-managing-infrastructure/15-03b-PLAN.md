---
phase: 15-self-managing-infrastructure
plan: 15-03b
title: Auto-Upgrade Extensions for Safety
depends_on:
  - Phase 6 (Auto-upgrade module)
  - Phase 15-03a (Chezmoi sync module)
status: not_started
---

# Plan 15-03b: Auto-Upgrade Extensions for Safety

## Objective

Extend the existing auto-upgrade module with pre-update validation and hooks to ensure safe deployments. This integrates the chezmoi sync module (15-03a) into the auto-upgrade workflow and adds build validation to catch errors before deployment.

**Critical Safety Feature**: Validate NixOS builds BEFORE deploying to prevent broken boots and ensure the golden generation rollback system (15-01) is only needed for runtime failures, not build errors.

## Success Criteria

- [ ] `preUpdateValidation` option added to auto-upgrade module
- [ ] `preUpdateHooks` option added for extensibility
- [ ] Build validation runs `nh os build` before `nh os switch`
- [ ] Build failures prevent deployment (no broken configs deployed)
- [ ] Chezmoi sync integrated as pre-update hook
- [ ] Service ordering ensures hooks run before upgrade
- [ ] Logging shows validation results clearly

## Context

**Current Auto-Upgrade Workflow** (Phase 6):
```
1. git pull nix-config repo
2. nh os switch -u (rebuild and switch)
```

**New Workflow with Extensions**:
```
1. Run pre-update hooks (e.g., chezmoi-pre-update.service)
   └─> chezmoi sync: fetch, rebase, re-add, commit, push
2. git pull nix-config repo
3. Validate build (nh os build)
   ├─ Success → proceed to step 4
   └─ Failure → abort, log error, notify user
4. Deploy (nh os switch -u)
5. If deploy fails → golden generation rollback (Phase 15-01)
```

**Why This Matters**:
- **Prevent broken boots**: Catch syntax errors, missing packages, etc. before deployment
- **Preserve dotfiles**: Chezmoi sync ensures local changes never lost
- **Extensibility**: preUpdateHooks allows adding more validations later
- **Safety layers**: Build validation + runtime validation + rollback = comprehensive safety

## Implementation Tasks

### Task 1: Extend Auto-Upgrade Module Options

**File**: `modules/services/system/auto-upgrade.nix`

**Add new options**:
```nix
# In options section, add:

preUpdateValidation = lib.mkOption {
  type = lib.types.bool;
  default = true;
  description = ''
    Validate NixOS build before deploying.
    Runs 'nh os build' to catch configuration errors early.
    Build failures prevent deployment, protecting against broken boots.
  '';
};

preUpdateHooks = lib.mkOption {
  type = lib.types.listOf lib.types.str;
  default = [];
  example = [ "chezmoi-pre-update.service" ];
  description = ''
    List of systemd services to run before the OS update.
    These services must complete successfully before the update proceeds.

    Common use cases:
    - chezmoi-pre-update.service (sync dotfiles)
    - backup-before-update.service (snapshot state)
    - custom-validation.service (project-specific checks)
  '';
};

hostCanCommitConfig = lib.mkOption {
  type = lib.types.bool;
  default = false;
  description = ''
    Allow this host to commit and push nix-config changes.

    When enabled:
    - Checks for uncommitted changes after deployment
    - Commits with format: "chore(hostname): auto-update timestamp"
    - Pushes to remote (fails gracefully if no network)

    Use cases:
    - Desktop hosts making manual config tweaks
    - Automated config generators

    Servers should typically leave this disabled (pull-only).
  '';
};
```

### Task 2: Update Auto-Upgrade Service Logic

**File**: `modules/services/system/auto-upgrade.nix`

**Modify service definition**:
```nix
systemd.services.auto-upgrade = {
  description = "NixOS Auto-Upgrade with Validation";

  # ... existing config (startAt, path, etc.)

  # Add hook dependencies
  after = cfg.preUpdateHooks ++ [ "network-online.target" ];
  wants = cfg.preUpdateHooks ++ [ "network-online.target" ];

  # Update script
  script = ''
    set -euo pipefail

    echo "=== NixOS Auto-Upgrade Started ==="
    logger -t auto-upgrade "Auto-upgrade started"

    # Pull latest config from git
    echo "Pulling latest nix-config from ${cfg.branch}..."
    if ! ${pkgs.git}/bin/git -C ${cfg.configPath} pull origin ${cfg.branch}; then
      echo "Error: Failed to pull latest config"
      logger -t auto-upgrade "ERROR: git pull failed"
      exit 1
    fi

    ${lib.optionalString cfg.preUpdateValidation ''
      # Validate build before deploying
      echo "=== Validating NixOS Build ==="
      logger -t auto-upgrade "Starting build validation"

      if ! ${pkgs.nh}/bin/nh os build ${cfg.configPath}; then
        echo "=== Build Validation FAILED ==="
        echo "Configuration has errors. Deployment aborted."
        echo "Review the errors above and fix the configuration."
        logger -t auto-upgrade "ERROR: Build validation failed, deployment aborted"

        # Don't exit 1 - we want systemd to record as "failed" but not retry immediately
        exit 1
      fi

      echo "=== Build Validation PASSED ==="
      logger -t auto-upgrade "Build validation passed"
    ''}

    # Deploy the new configuration
    echo "=== Deploying New Configuration ==="
    logger -t auto-upgrade "Starting deployment"

    if ! ${pkgs.nh}/bin/nh os switch -u ${cfg.configPath}; then
      echo "=== Deployment FAILED ==="
      echo "System may rollback to golden generation on next boot."
      logger -t auto-upgrade "ERROR: Deployment failed"
      exit 1
    fi

    echo "=== Deployment Successful ==="
    logger -t auto-upgrade "Deployment completed successfully"

    ${lib.optionalString cfg.hostCanCommitConfig ''
      # Optional: Commit config changes if host is allowed
      echo "=== Checking for config changes to commit ==="

      cd ${cfg.configPath}

      # Check if there are uncommitted changes
      if ! ${pkgs.git}/bin/git diff --quiet || ! ${pkgs.git}/bin/git diff --cached --quiet; then
        HOSTNAME=$(${pkgs.nettools}/bin/hostname)
        TIMESTAMP=$(${pkgs.coreutils}/bin/date -Iseconds)

        echo "Committing config changes..."
        ${pkgs.git}/bin/git add .
        ${pkgs.git}/bin/git commit -m "chore($HOSTNAME): auto-update $TIMESTAMP"

        # Try to push (fail gracefully if no network)
        if ${pkgs.git}/bin/git push origin ${cfg.branch}; then
          echo "Config changes pushed successfully"
          logger -t auto-upgrade "Committed and pushed config changes"
        else
          echo "Warning: Could not push config changes (no network?)"
          logger -t auto-upgrade "WARNING: Could not push config changes"
        fi
      else
        echo "No config changes to commit"
      fi
    ''}

    echo "=== Auto-Upgrade Complete ==="
  '';

  serviceConfig = {
    Type = "oneshot";
    # ... existing serviceConfig
  };
};
```

**Key Changes**:
1. Added `after` and `wants` dependencies on preUpdateHooks
2. Added build validation section (nh os build)
3. Build failures abort deployment with clear error message
4. Optional config commit logic (hostCanCommitConfig)
5. Enhanced logging at each step

### Task 3: Update Role Configurations

**File**: `roles/form-desktop.nix`

Add auto-upgrade configuration after chezmoi sync:
```nix
# AUTO-UPGRADE (extended with validation and hooks)
myModules.services.system.autoUpgrade = {
  # ... existing config (enable, configPath, branch, etc.)

  # NEW: Add pre-update hooks
  preUpdateHooks = lib.mkDefault [
    "chezmoi-pre-update.service"  # From 15-03a
  ];

  # NEW: Enable build validation
  preUpdateValidation = lib.mkDefault true;

  # NEW: Desktops can commit config changes
  hostCanCommitConfig = lib.mkDefault true;
};
```

**File**: `roles/form-laptop.nix` (same as desktop)

**File**: `roles/form-server.nix`:
```nix
myModules.services.system.autoUpgrade = {
  # ... existing config

  # Servers also get hooks and validation
  preUpdateHooks = lib.mkDefault [
    "chezmoi-pre-update.service"
  ];

  preUpdateValidation = lib.mkDefault true;

  # Servers typically don't commit config (pull-only)
  hostCanCommitConfig = lib.mkDefault false;
};
```

**File**: `roles/form-pi.nix` (same as server)

## Testing

### Test 1: Build Validation Catches Errors

```bash
# On griefling VM
# 1. Introduce a syntax error in config
cd /home/rain/nix-config
echo "invalid syntax here" >> hosts/griefling/default.nix
git add .
git commit -m "test: introduce build error"
git push

# 2. Wait for auto-upgrade to run (or trigger manually)
sudo systemctl start auto-upgrade.service

# 3. Check logs
journalctl -u auto-upgrade.service -f

# Expected output:
# "=== Validating NixOS Build ==="
# ... build errors ...
# "=== Build Validation FAILED ==="
# "Configuration has errors. Deployment aborted."
# Service status: failed

# 4. Verify system didn't switch to broken config
nixos-rebuild list-generations
# Current generation should be unchanged

# 5. Fix the error and push
git revert HEAD
git push

# 6. Next auto-upgrade should succeed
```

### Test 2: Pre-Update Hooks Run in Order

```bash
# On malphas (desktop)
# 1. Make dotfile change
echo "# Test change $(date)" >> ~/.bashrc

# 2. Trigger auto-upgrade
sudo systemctl start auto-upgrade.service

# 3. Watch service execution
journalctl -f

# Expected sequence:
# 1. chezmoi-pre-update.service starts
#    - "Fetching remote changes..."
#    - "Capturing current dotfiles..."
#    - "Successfully pushed changes"
# 2. auto-upgrade.service starts
#    - "Pulling latest nix-config..."
#    - "=== Validating NixOS Build ==="
#    - "=== Build Validation PASSED ==="
#    - "=== Deploying New Configuration ==="
#    - "=== Deployment Successful ==="

# 4. Verify dotfile was synced
cd ~/.local/share/chezmoi
jj log -r @
# Should show recent commit with bashrc change
```

### Test 3: Network Failure Graceful Degradation

```bash
# On griefling VM
# 1. Disconnect network
sudo systemctl stop NetworkManager

# 2. Make local dotfile change
echo "# Local change $(date)" >> ~/.bashrc

# 3. Trigger auto-upgrade
sudo systemctl start auto-upgrade.service

# 4. Check logs
journalctl -u chezmoi-pre-update.service
# Expected: "Warning: Could not fetch (no network?)"
# State: "fetch-failed"

journalctl -u auto-upgrade.service
# Expected: May fail at git pull step OR succeed if no upstream changes

# 5. Reconnect network
sudo systemctl start NetworkManager

# 6. Next auto-upgrade should sync the pending dotfile change
```

### Test 4: Config Commit (Desktop Only)

```bash
# On malphas (hostCanCommitConfig = true)
# 1. Make local config change
cd /home/rain/nix-config
echo "# Local tweak" >> hosts/malphas/default.nix

# 2. Rebuild manually (simulates what auto-upgrade does)
nh os switch

# 3. Trigger auto-upgrade
sudo systemctl start auto-upgrade.service

# 4. Check if config was committed
cd /home/rain/nix-config
git log -1
# Expected: "chore(malphas): auto-update <timestamp>"

# 5. Verify on server (pull-only)
# On griefling (hostCanCommitConfig = false)
# Make local change, trigger auto-upgrade
# Expected: No commit created
```

## Documentation

**Update module header** in `auto-upgrade.nix`:
```nix
# NixOS Auto-Upgrade Module
#
# Automatically updates NixOS configuration with safety features:
# - Pre-update hooks (e.g., chezmoi dotfile sync)
# - Build validation (catch errors before deployment)
# - Optional config commit (for hosts that make local changes)
# - Integration with golden generation rollback (Phase 15-01)
#
# Safety Workflow:
#   1. Pre-update hooks (chezmoi sync, backups, etc.)
#   2. Pull latest config from git
#   3. Validate build (nh os build)
#   4. Deploy only if build succeeds (nh os switch)
#   5. If runtime failure → golden generation rollback
#
# Options:
#   - preUpdateHooks: List of services to run before update
#   - preUpdateValidation: Validate build before deploying (default: true)
#   - hostCanCommitConfig: Allow host to push config changes (default: false)
```

## Error Handling

**Build Validation Failures**:
- Service exits with code 1 (systemd marks as failed)
- No deployment happens (nh os switch never runs)
- System remains on current generation
- User alerted via systemd journal + optional monitoring

**Hook Failures**:
- If hook fails, auto-upgrade won't run (systemd dependency)
- Use `wants` instead of `requires` to make hooks optional
- Currently uses `wants` so failed hooks don't block upgrade

**Network Failures**:
- Git pull failure → abort (can't get latest config)
- Chezmoi fetch failure → log warning, continue (graceful degradation)
- Config push failure → log warning, continue (retry next time)

## Known Issues / Future Improvements

1. **Hook failure handling**: Should hooks block upgrade or just warn?
2. **Notification**: Add optional notification on failure (email, Matrix, etc.)
3. **Retry logic**: Failed updates don't auto-retry, wait for next timer
4. **Parallel validation**: Could validate while hooks run (save time)
5. **Config commit conflicts**: hostCanCommitConfig could conflict with other hosts

## Dependencies

- Phase 6: Auto-upgrade module (being extended)
- Phase 15-03a: Chezmoi sync module (hooked in)
- Phase 15-01: Golden generation rollback (runtime safety)

## Security Considerations

1. **Build validation**: Prevents deployment of malicious configs with syntax errors
2. **Hook execution order**: Hooks run before config pull (can't be bypassed)
3. **Config commit**: Only trusted hosts should have hostCanCommitConfig enabled
4. **Log auditing**: All actions logged for security review

## Rollback Plan

If extensions cause issues:

1. **Disable validation**: Set `preUpdateValidation = false;`
2. **Remove hooks**: Set `preUpdateHooks = [];`
3. **Disable config commit**: Set `hostCanCommitConfig = false;`
4. **Revert module**: Roll back auto-upgrade.nix to Phase 6 version

## Success Metrics

- [ ] Build validation catches errors before deployment
- [ ] Pre-update hooks run in correct order
- [ ] Chezmoi sync integrated successfully
- [ ] Network failures handled gracefully
- [ ] Desktop hosts can commit config changes
- [ ] Server hosts remain pull-only
- [ ] All logging clear and actionable

## Next Steps

After this plan completes:
- **15-03c**: Secret migration and comprehensive testing
