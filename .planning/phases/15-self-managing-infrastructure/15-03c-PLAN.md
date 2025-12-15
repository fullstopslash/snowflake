---
phase: 15-self-managing-infrastructure
plan: 15-03c
title: Secret Migration and Comprehensive Testing
depends_on:
  - Phase 4 (SOPS secrets)
  - Phase 15-03a (Chezmoi sync module)
  - Phase 15-03b (Auto-upgrade extensions)
status: not_started
---

# Plan 15-03c: Secret Migration and Comprehensive Testing

## Objective

Migrate secrets from chezmoi templates to SOPS, initialize chezmoi with jj on all hosts, and perform comprehensive end-to-end testing of the complete GitOps workflow. This completes the decentralized configuration management system.

**Critical Goal**: Ensure no secrets leak into chezmoi git repo. All sensitive data must live in SOPS, chezmoi only manages non-sensitive dotfile structure.

## Success Criteria

### Secret Migration
- [ ] All secrets identified in chezmoi templates
- [ ] Secrets moved to SOPS (secrets/dotfiles.yaml or existing files)
- [ ] Chezmoi templates updated to reference SOPS-decrypted values
- [ ] No secrets remain in chezmoi git history
- [ ] Templates validated on malphas before rolling out

### Chezmoi Initialization
- [ ] All hosts have chezmoi initialized with jj co-located repo
- [ ] SSH keys deployed via SOPS for git push access
- [ ] Initial sync successful on all hosts
- [ ] jj log shows proper history on each host

### Comprehensive Testing
- [ ] Multi-host concurrent edits test (conflict handling)
- [ ] Build validation test (catch errors before deploy)
- [ ] Network failure test (graceful degradation)
- [ ] Full auto-upgrade workflow test (dotfiles → config → deploy)
- [ ] Golden generation rollback integration test
- [ ] Manual recovery procedures documented and tested

### Documentation
- [ ] Architecture documentation (how it all fits together)
- [ ] User guide (manual commands, debugging)
- [ ] Recovery procedures (what to do when things break)
- [ ] Migration guide (for other users adopting this setup)

## Context

**Missing Template Variables** (from earlier context):
- `acoustid_api` - API key for AcoustID music fingerprinting
- `email_personal` - Personal email address
- `desktop` - Desktop environment/WM name (could be non-secret)
- `name` - User's full name (could be non-secret)

**Current State**:
- Chezmoi templates use `{{ .variable }}` syntax for templating
- Some variables are secrets (API keys), some are config (name, email)
- Secrets stored in `.chezmoidata.yaml` or similar (INSECURE - tracked in git)
- Need to separate secrets (SOPS) from config (chezmoi data files)

## Implementation Tasks

### Task 1: Audit Chezmoi Templates for Secrets

**Manual audit on malphas**:
```bash
# 1. Find all template files
cd ~/.local/share/chezmoi
find . -type f -name "*.tmpl" -o -name ".chezmoi*"

# 2. Search for template variables
grep -r "{{" . | grep -v ".git"

# 3. Identify secrets vs non-secrets
# Secrets: API keys, tokens, passwords, private emails
# Non-secrets: Public emails, name, desktop environment, etc.

# 4. Document findings
echo "=== Chezmoi Template Audit ===" > /tmp/chezmoi-audit.txt
echo "" >> /tmp/chezmoi-audit.txt
echo "Secrets found:" >> /tmp/chezmoi-audit.txt
grep -r "acoustid_api\|email_personal" . >> /tmp/chezmoi-audit.txt
echo "" >> /tmp/chezmoi-audit.txt
echo "Non-secrets found:" >> /tmp/chezmoi-audit.txt
grep -r "desktop\|name" . >> /tmp/chezmoi-audit.txt
```

**Expected findings**:
- `acoustid_api` → SECRET (API key)
- `email_personal` → MAYBE SECRET (depends on if it's public)
- `desktop` → NON-SECRET (just "sway" or "hyprland")
- `name` → NON-SECRET (public identity)

### Task 2: Migrate Secrets to SOPS

**Decision**: Create new `secrets/dotfiles.yaml` or use existing secret files

**Option A: New dotfiles.yaml file**:
```yaml
# secrets/dotfiles.yaml
acoustid_api: "secret-api-key-here"
email_personal: "private@example.com"  # If truly private
```

**Option B: Use existing secrets** (if they already exist):
```yaml
# If acoustid_api already in secrets/services.yaml or similar
# Just reference it from chezmoi templates
```

**Add to SOPS configuration**:
```nix
# In appropriate host config (hosts/malphas/secrets.nix)
sops.secrets.acoustid_api = {
  sopsFile = lib.custom.relativeToRoot "secrets/dotfiles.yaml";
  path = "/run/secrets/acoustid_api";
  owner = config.users.users.rain.name;
  mode = "0400";
};

sops.secrets.email_personal = {
  sopsFile = lib.custom.relativeToRoot "secrets/dotfiles.yaml";
  path = "/run/secrets/email_personal";
  owner = config.users.users.rain.name;
  mode = "0400";
};
```

**Encrypt secrets**:
```bash
cd /home/rain/nix-config

# Create secrets file (if new)
cat > secrets/dotfiles.yaml <<EOF
acoustid_api: REPLACEME
email_personal: REPLACEME
EOF

# Encrypt with SOPS
sops secrets/dotfiles.yaml
# (Editor opens, replace REPLACEME with actual values)

# Verify encryption
sops -d secrets/dotfiles.yaml  # Should decrypt properly

# Add to git
git add secrets/dotfiles.yaml
git commit -m "feat(secrets): add dotfiles secrets"
```

### Task 3: Update Chezmoi Templates

**Strategy**: Use file includes to reference SOPS-decrypted secrets

**Example transformation**:

**Before** (in chezmoi template):
```bash
# In some_config_file.tmpl
api_key = "{{ .acoustid_api }}"
email = "{{ .email_personal }}"
```

**After** (reference SOPS):
```bash
# In some_config_file.tmpl
api_key = "{{ include "/run/secrets/acoustid_api" | trim }}"
email = "{{ include "/run/secrets/email_personal" | trim }}"
```

**Or use environment variables** (if chezmoi supports):
```bash
# Set in chezmoi config
api_key = "{{ env "ACOUSTID_API" }}"
```

**Update .chezmoidata.yaml** (remove secrets):
```yaml
# .chezmoidata.yaml (NON-SECRET config only)
name: "Rain"
desktop: "hyprland"
# acoustid_api: REMOVED (now in SOPS)
# email_personal: REMOVED (now in SOPS)
```

**Validate templates**:
```bash
# Test chezmoi template rendering (dry-run)
chezmoi apply --dry-run --verbose

# Expected: Templates render correctly with SOPS values
# No errors about missing variables
```

### Task 4: Clean Git History (If Secrets Were Committed)

**WARNING**: Only needed if secrets were committed to chezmoi repo in plain text

**Option A: BFG Repo-Cleaner** (recommended):
```bash
cd ~/.local/share/chezmoi

# Backup first!
cd ..
cp -r chezmoi chezmoi-backup

cd chezmoi

# Install BFG
nix-shell -p bfg-repo-cleaner

# Remove secrets file from history
bfg --delete-files .chezmoidata.yaml
bfg --replace-text passwords.txt  # File with "SECRET==>REMOVED" patterns

# Clean up
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Force push (DESTRUCTIVE - only if repo is private/personal)
git push --force
```

**Option B: Skip if repo is private** and just remove from current version:
```bash
# Remove secrets from current commit
cd ~/.local/share/chezmoi
git rm .chezmoidata.yaml  # If it contained secrets
git commit -m "security: remove secrets (moved to SOPS)"
git push
```

### Task 5: Initialize Chezmoi with jj on All Hosts

**Hosts to initialize**:
- malphas (desktop) - PRIMARY, test first
- griefling (VM) - secondary testing
- Other hosts as needed

**Initialization script** (run on each host):
```bash
#!/usr/bin/env bash
set -euo pipefail

HOSTNAME=$(hostname)
CHEZMOI_REPO="git@github.com:rain/dotfiles.git"  # User must specify

echo "=== Initializing chezmoi with jj on $HOSTNAME ==="

# 1. Check if chezmoi already initialized
if [ ! -d ~/.local/share/chezmoi ]; then
  echo "Initializing chezmoi from $CHEZMOI_REPO..."
  chezmoi init "$CHEZMOI_REPO"
else
  echo "Chezmoi already initialized"
fi

cd ~/.local/share/chezmoi

# 2. Convert to jj co-located repo
if [ ! -d .jj ]; then
  echo "Converting to jj co-located repo..."
  jj git init --colocate
else
  echo "jj already initialized"
fi

# 3. Verify jj working
echo "jj status:"
jj status

echo "jj log (last 5):"
jj log --limit 5

# 4. Initial sync
echo "Performing initial sync..."
jj git fetch
jj rebase -d @- -s @

# 5. Capture current state
echo "Capturing current dotfiles..."
chezmoi re-add

# 6. Commit
echo "Creating initial jj commit..."
jj describe -m "chore($HOSTNAME): initial jj setup - $(date -Iseconds)"

# 7. Push
echo "Pushing to remote..."
if jj git push; then
  echo "✓ Push successful"
else
  echo "⚠ Push failed (no network or auth issue?)"
fi

echo "=== Chezmoi + jj initialization complete on $HOSTNAME ==="
echo ""
echo "Manual commands:"
echo "  chezmoi-sync        - Sync dotfiles"
echo "  chezmoi-status      - Show sync status"
echo "  chezmoi-show-conflicts - Check for conflicts"
```

**Run on each host**:
```bash
# On malphas (test first)
bash init-chezmoi-jj.sh

# On griefling VM
bash init-chezmoi-jj.sh

# Verify state
chezmoi-status
cat /var/lib/chezmoi-sync/last-sync-status
```

### Task 6: Comprehensive Testing

#### Test 1: Multi-Host Concurrent Edit (Conflict Simulation)

**Purpose**: Verify jj handles concurrent edits without data loss

**Steps**:
```bash
# Simultaneously on malphas and griefling:

# Malphas
cd ~/.local/share/chezmoi
echo "# Malphas change $(date)" >> dot_bashrc
jj describe -m "test: malphas bashrc edit"
jj git push

# Griefling (within seconds of malphas)
cd ~/.local/share/chezmoi
echo "# Griefling change $(date)" >> dot_bashrc
chezmoi-sync  # Will fetch malphas's change

# On griefling, verify both changes preserved:
jj log --limit 10
cat dot_bashrc | grep -E "Malphas|Griefling"

# Expected: BOTH lines present in file or as separate commits
# jj creates parallel commits for conflicts
```

**Success criteria**:
- ✅ Both changes visible in jj log
- ✅ No "merge conflict" errors
- ✅ Sync completes without manual intervention
- ✅ Both commits eventually pushed to remote

#### Test 2: Build Validation Catches Errors

**Purpose**: Verify preUpdateValidation prevents broken deployments

**Steps**:
```bash
# On griefling VM
cd /home/rain/nix-config

# Introduce syntax error
echo "invalid { nix syntax" >> hosts/griefling/default.nix
git add .
git commit -m "test: intentional build error"
git push origin dev

# Wait for auto-upgrade or trigger manually
sudo systemctl start auto-upgrade.service

# Watch logs
journalctl -u auto-upgrade.service -f

# Expected output:
# "=== Validating NixOS Build ==="
# ... build errors ...
# "=== Build Validation FAILED ==="
# "Deployment aborted"

# Verify system unchanged
nixos-rebuild list-generations
# Current generation should match before test

# Fix error
git revert HEAD
git push origin dev

# Next auto-upgrade should succeed
```

**Success criteria**:
- ✅ Build validation runs before deployment
- ✅ Build errors caught and logged
- ✅ Deployment aborted (no broken config deployed)
- ✅ System remains on working generation

#### Test 3: Network Failure Graceful Degradation

**Purpose**: Verify system continues to work offline

**Steps**:
```bash
# On griefling VM
# 1. Make local dotfile change
echo "# Offline change $(date)" >> ~/.bashrc

# 2. Disconnect network
sudo systemctl stop NetworkManager
ping -c 1 1.1.1.1  # Verify offline

# 3. Trigger auto-upgrade
sudo systemctl start auto-upgrade.service

# 4. Check logs
journalctl -u chezmoi-pre-update.service
# Expected: "Warning: Could not fetch (no network?)"

journalctl -u auto-upgrade.service
# Expected: May fail at git pull, OR succeed if no upstream changes

# 5. Verify state
cat /var/lib/chezmoi-sync/last-sync-status
# Expected: "fetch-failed"

# 6. Reconnect
sudo systemctl start NetworkManager

# 7. Next auto-upgrade should sync pending change
sudo systemctl start auto-upgrade.service
journalctl -u chezmoi-pre-update.service | tail -20
# Expected: "Successfully pushed changes"
```

**Success criteria**:
- ✅ Chezmoi sync fails gracefully (no service failure)
- ✅ Auto-upgrade continues (or fails gracefully at git pull)
- ✅ State file tracks failure ("fetch-failed")
- ✅ Next sync with network recovers automatically

#### Test 4: Full Auto-Upgrade Workflow (Golden Path)

**Purpose**: Verify entire workflow end-to-end

**Steps**:
```bash
# On malphas (desktop with all features enabled)

# 1. Make dotfile change
echo "# Test full workflow $(date)" >> ~/.bashrc

# 2. Make config change (if hostCanCommitConfig enabled)
cd /home/rain/nix-config
echo "# Test config change" >> hosts/malphas/default.nix
nh os switch  # Apply locally

# 3. Wait for auto-upgrade timer OR trigger manually
sudo systemctl start auto-upgrade.service

# 4. Watch full workflow
journalctl -f -u chezmoi-pre-update.service -u auto-upgrade.service

# Expected sequence:
# [chezmoi-pre-update] Fetching remote changes...
# [chezmoi-pre-update] Capturing current dotfiles...
# [chezmoi-pre-update] Successfully pushed changes
# [auto-upgrade] Pulling latest nix-config...
# [auto-upgrade] === Validating NixOS Build ===
# [auto-upgrade] === Build Validation PASSED ===
# [auto-upgrade] === Deploying New Configuration ===
# [auto-upgrade] === Deployment Successful ===
# [auto-upgrade] Committing config changes...
# [auto-upgrade] Config changes pushed successfully

# 5. Verify all changes persisted
cd ~/.local/share/chezmoi
jj log -r @
# Should show commit with bashrc change

cd /home/rain/nix-config
git log -1
# Should show auto-commit with config change (if hostCanCommitConfig)

# 6. On griefling, verify changes propagated
# Wait for griefling's auto-upgrade, then:
cd ~/.local/share/chezmoi
jj log --limit 5
# Should show malphas's dotfile commit

cd /home/rain/nix-config
git log --limit 5
# Should show malphas's config commit
```

**Success criteria**:
- ✅ Dotfile changes synced before config pull
- ✅ Build validation passes
- ✅ Deployment succeeds
- ✅ Config changes committed (desktop only)
- ✅ All changes propagate to other hosts

#### Test 5: Golden Generation Rollback Integration

**Purpose**: Verify rollback system activates on bad deployments

**Steps**:
```bash
# On griefling VM

# 1. Note current golden generation
show-boot-status
# Note the golden generation number

# 2. Deploy a config that passes build but fails at runtime
# Example: Break SSH by misconfiguring sshd
cd /home/rain/nix-config
cat >> hosts/griefling/default.nix <<EOF
# Intentionally break SSH
services.openssh.settings.PermitRootLogin = lib.mkForce "invalid-value";
EOF

git add .
git commit -m "test: break SSH (runtime failure)"
git push origin dev

# 3. Wait for auto-upgrade OR trigger
sudo systemctl start auto-upgrade.service

# Expected: Build validation PASSES (syntax is valid)
# Deployment happens, but SSH breaks

# 4. Reboot to trigger validation
sudo reboot

# 5. After reboot, check boot status
show-boot-status
# Expected: "Boot failure count: 1 / 2"

# 6. Reboot again (second failure)
sudo reboot

# 7. After second reboot, system should rollback
show-boot-status
# Expected: System rolled back to golden generation
# Boot failure count: 0 (reset after rollback)

# 8. Verify system on golden generation
nixos-rebuild list-generations
# Current generation should match golden

# 9. Fix config and redeploy
cd /home/rain/nix-config
git revert HEAD
git push origin dev
# Wait for auto-upgrade or trigger manually
```

**Success criteria**:
- ✅ Build validation passes (runtime failures not caught by build)
- ✅ First boot failure increments counter
- ✅ Second boot failure triggers rollback
- ✅ System boots into golden generation
- ✅ Counter resets after rollback

### Task 7: Documentation

#### Create: `docs/decentralized-gitops.md`

**Content**:
```markdown
# Decentralized GitOps Architecture

## Overview

This NixOS configuration implements a decentralized GitOps system where:
- Multiple hosts can independently commit changes
- Changes automatically sync and merge without conflicts
- Hosts validate before deploying to prevent broken boots
- Failed deployments trigger automatic rollback

## Components

1. **Chezmoi + Jujutsu (jj)** - Conflict-free dotfile sync
2. **Auto-Upgrade with Validation** - Safe config deployment
3. **Golden Generation Rollback** - Boot failure recovery

## Workflow

### Dotfile Changes

1. Edit dotfiles locally on any host
2. Auto-upgrade triggers chezmoi-pre-update.service
3. Sync: `jj git fetch → jj rebase → chezmoi re-add → jj describe → jj git push`
4. Conflicts become parallel commits (auto-resolved by jj)
5. All hosts eventually pull and reconcile

### Config Changes

1. Edit nix-config locally (or via git)
2. Auto-upgrade pulls latest changes
3. Build validation (`nh os build`) catches errors
4. If build passes → deploy (`nh os switch`)
5. If deploy fails → golden generation rollback on next boot

## Why Jujutsu?

jj provides conflict-free synchronization:
- Concurrent edits become separate commits
- No manual merge conflict resolution
- All changes preserved in history
- Simple automation (no complex merge logic)

Example:
```
Host A: edits .bashrc → commits → pushes
Host B: edits .bashrc → commits → fetches → rebases → TWO COMMITS
```

Compare to git:
```
Host A: edits .bashrc → commits → pushes
Host B: edits .bashrc → commits → pulls → CONFLICT → blocks automation
```

## Manual Commands

### Chezmoi
- `chezmoi-sync` - Manually sync dotfiles
- `chezmoi-status` - Show sync status and jj log
- `chezmoi-show-conflicts` - Check for conflicts

### Boot/Rollback
- `show-boot-status` - Display boot validation status
- `pin-golden` - Manually pin current generation as golden
- `show-golden` - Show golden generation info
- `rollback-to-golden` - Manually rollback to golden

### Auto-Upgrade
- `systemctl status auto-upgrade.service` - Check upgrade status
- `journalctl -u auto-upgrade.service` - View upgrade logs
- `systemctl start auto-upgrade.service` - Trigger manual upgrade

## Debugging

### Dotfile sync issues
```bash
cd ~/.local/share/chezmoi
jj status
jj log --limit 10
cat /var/lib/chezmoi-sync/last-sync-status
```

### Build validation failures
```bash
journalctl -u auto-upgrade.service | grep "Build Validation"
nh os build  # Manually validate
```

### Boot failures
```bash
show-boot-status
journalctl -t golden-generation
```

## Recovery Procedures

See `docs/recovery-procedures.md`
```

#### Create: `docs/recovery-procedures.md`

**Content**:
```markdown
# Recovery Procedures

## Chezmoi Sync Stuck

**Symptoms**: chezmoi-sync fails repeatedly, state file shows "fetch-failed"

**Recovery**:
```bash
cd ~/.local/share/chezmoi

# Check jj status
jj status
jj log --conflicts

# Option 1: Reset to remote
jj git fetch
jj rebase -d @- -s @

# Option 2: Nuclear - reinitialize jj
rm -rf .jj
jj git init --colocate
jj git fetch
jj rebase -d @- -s @

# Verify
jj status
chezmoi-sync
```

## Build Validation False Positive

**Symptoms**: Build validation fails but config is actually valid

**Recovery**:
```bash
# Disable validation temporarily
cd /home/rain/nix-config
# In host config:
# myModules.services.system.autoUpgrade.preUpdateValidation = false;

nh os switch

# Investigate why validation failed
journalctl -u auto-upgrade.service | grep "Build Validation"

# Re-enable validation after fix
```

## Auto-Upgrade Stuck

**Symptoms**: auto-upgrade.service fails repeatedly

**Recovery**:
```bash
# Check logs
journalctl -u auto-upgrade.service

# Check hooks
journalctl -u chezmoi-pre-update.service

# Disable auto-upgrade temporarily
sudo systemctl stop auto-upgrade.timer
sudo systemctl disable auto-upgrade.timer

# Manual update
cd /home/rain/nix-config
git pull origin dev
nh os build  # Validate
nh os switch  # Deploy

# Re-enable after fix
sudo systemctl enable auto-upgrade.timer
sudo systemctl start auto-upgrade.timer
```

## Boot Loop (Rollback Failed)

**Symptoms**: System boots into bad generation repeatedly

**Recovery via TTY**:
```bash
# At boot menu, select working generation manually

# After boot, check status
show-boot-status

# Reset boot failures
reset-boot-failures

# Pin current working generation
pin-golden

# Fix config
cd /home/rain/nix-config
git revert <bad-commit>
git push origin dev

# Rebuild
nh os switch
```

## Lost Dotfile Changes

**Symptoms**: Dotfile changes not showing up in chezmoi repo

**Recovery**:
```bash
cd ~/.local/share/chezmoi

# Check jj log
jj log --limit 20

# Capture current state
chezmoi re-add

# Commit and push
jj describe -m "recovery: capture lost changes"
jj git push

# Verify
jj log -r @
```

## Secrets Leaked to Chezmoi Repo

**Symptoms**: Secret accidentally committed to dotfiles repo

**Immediate Action**:
```bash
cd ~/.local/share/chezmoi

# Remove secret from current commit
git rm <file-with-secret>
git commit -m "security: remove leaked secret"
git push --force  # If repo is private/personal

# Rotate compromised secret immediately

# Clean git history (if needed)
# Use BFG Repo-Cleaner or git filter-branch
```

**Prevention**: Always use SOPS for secrets, never commit to chezmoi repo
```

#### Create: `docs/migration-guide.md`

**Content** (for other users adopting this setup):
```markdown
# Migration Guide: Decentralized GitOps Setup

Guide for adopting this multi-host NixOS + chezmoi GitOps architecture.

## Prerequisites

- NixOS hosts with SSH access
- Git repository for nix-config
- Git repository for dotfiles (chezmoi)
- SOPS configured with age/SSH keys

## Step 1: Enable SOPS Secrets (if not already)

See Phase 4 documentation.

## Step 2: Enable Auto-Upgrade Module

In role or host config:
```nix
myModules.services.system.autoUpgrade = {
  enable = true;
  configPath = "/home/user/nix-config";
  branch = "main";
  preUpdateValidation = true;
};
```

## Step 3: Enable Golden Generation Rollback

In role or host config:
```nix
myModules.system.boot.goldenGeneration = {
  enable = true;
  validateServices = [ "sshd.service" ];
  autoPinAfterBoot = true;
};
```

## Step 4: Migrate Chezmoi Secrets to SOPS

1. Audit chezmoi templates: `grep -r "{{" ~/.local/share/chezmoi`
2. Identify secrets (API keys, tokens, passwords)
3. Create `secrets/dotfiles.yaml` with secrets
4. Encrypt with SOPS: `sops secrets/dotfiles.yaml`
5. Update chezmoi templates to use file includes: `{{ include "/run/secrets/api_key" }}`
6. Remove secrets from `.chezmoidata.yaml`
7. Test: `chezmoi apply --dry-run`

## Step 5: Enable Chezmoi Sync Module

In role or host config:
```nix
myModules.services.dotfiles.chezmoiSync = {
  enable = true;
  repoUrl = "git@github.com:user/dotfiles.git";
  syncBeforeUpdate = true;
};

myModules.services.system.autoUpgrade.preUpdateHooks = [
  "chezmoi-pre-update.service"
];
```

## Step 6: Initialize Chezmoi with jj

On each host:
```bash
# Initialize chezmoi
chezmoi init git@github.com:user/dotfiles.git

# Convert to jj
cd ~/.local/share/chezmoi
jj git init --colocate

# Initial sync
chezmoi-sync
```

## Step 7: Test

1. Make dotfile change on host A
2. Wait for auto-upgrade or trigger manually
3. Verify sync on host B
4. Test conflict handling (edit same file on both hosts)
5. Test build validation (introduce syntax error)

## Step 8: Monitor and Iterate

- Check logs: `journalctl -u auto-upgrade.service`
- Check sync status: `chezmoi-status`
- Check boot status: `show-boot-status`
- Adjust timers, validation rules, etc. as needed
```

## Success Metrics

- [ ] Secrets migrated to SOPS (no secrets in chezmoi repo)
- [ ] Chezmoi initialized with jj on all hosts
- [ ] Multi-host conflict test passes (both changes preserved)
- [ ] Build validation test passes (errors caught)
- [ ] Network failure test passes (graceful degradation)
- [ ] Full workflow test passes (dotfiles → config → deploy)
- [ ] Golden generation integration test passes (rollback works)
- [ ] Documentation complete and tested

## Dependencies

- Phase 4: SOPS (for secrets)
- Phase 15-03a: Chezmoi sync module
- Phase 15-03b: Auto-upgrade extensions
- Phase 15-01: Golden generation rollback

## Security Considerations

1. **Secret rotation**: After migration, rotate any secrets that may have been in git
2. **History cleaning**: Use BFG or filter-branch if secrets were in git history
3. **Access control**: Ensure only authorized hosts have push access
4. **Audit trail**: All changes logged in git history (chezmoi + nix-config)

## Rollback Plan

If migration causes issues:

1. **Disable chezmoi sync**: `myModules.services.dotfiles.chezmoiSync.enable = false;`
2. **Disable validation**: `preUpdateValidation = false;`
3. **Manual operations**: Use chezmoi manually without automation
4. **Revert secrets**: Temporarily use old chezmoi data files while debugging

## Next Steps

After Phase 15-03 completes:
- Phase 15-04: Advanced monitoring and alerting
- Phase 15-05: Multi-repo GitOps expansion
- Phase 15-06: Homelab orchestration
