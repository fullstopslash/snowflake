# Decentralized GitOps Architecture

## Overview

This NixOS configuration implements a decentralized GitOps system where:
- Multiple hosts can independently commit changes
- Changes automatically sync and merge without conflicts
- Hosts validate before deploying to prevent broken boots
- Failed deployments trigger automatic rollback

## Components

### 1. Chezmoi + Jujutsu (jj) - Conflict-free dotfile sync

**Why jj instead of git?**
- Concurrent edits become separate commits (no merge conflicts)
- No manual conflict resolution needed
- All changes preserved in history
- Simple automation (no complex merge logic)
- Offline-first design

**How it works:**
```
Host A: edits .bashrc → commits → pushes
Host B: edits .bashrc → commits → fetches → rebases → TWO COMMITS EXIST
```

Compare to git:
```
Host A: edits .bashrc → commits → pushes
Host B: edits .bashrc → commits → pulls → CONFLICT → blocks automation
```

### 2. Auto-Upgrade with Validation - Safe config deployment

**Pre-deployment validation:**
- Build validation (`nh os build`) catches syntax errors
- Validation checks ensure critical services will start
- Failed validation = no deployment

**Workflow:**
1. Pull latest nix-config changes
2. Run build validation
3. If build passes → deploy (`nh os switch`)
4. If build fails → rollback git changes, abort

### 3. Golden Generation Rollback - Boot failure recovery

**Boot validation:**
- Validates critical services (SSH, Tailscale, etc.) after boot
- Tracks boot failures (max 2 attempts)
- Automatic rollback to last known-good configuration

**How it works:**
1. System boots into new generation
2. Validates required services are active
3. If validation fails → increment failure counter
4. On 2nd failure → rollback to golden generation
5. On success → pin current generation as new golden

## Full Workflow

### Dotfile Changes

1. Edit dotfiles locally on any host
2. Auto-upgrade triggers `chezmoi-pre-update.service`
3. Sync workflow:
   ```
   jj git fetch → jj rebase → chezmoi re-add → jj describe → jj git push
   ```
4. Conflicts become parallel commits (auto-resolved by jj)
5. All hosts eventually pull and reconcile

### Config Changes

1. Edit nix-config locally (or via git)
2. Auto-upgrade pulls latest changes
3. Build validation (`nh os build`) catches errors
4. If build passes → deploy (`nh os switch`)
5. If deploy fails → golden generation rollback on next boot

### Secret Management

**All secrets managed via SOPS:**
- Secrets stored in `nix-secrets/sops/*.yaml`
- Encrypted with age keys
- Decrypted to `/run/secrets/*` at boot
- Chezmoi templates reference SOPS secrets via file includes

**Example:**
```bash
# Chezmoi template (beets config)
acoustid:
  apikey: {{ include "/run/secrets/acoustid_api" | trim }}

# SOPS secret (nix-secrets/sops/shared.yaml)
dotfiles:
    acoustid_api: iC9LdEPhyb

# NixOS config (chezmoi-sync.nix)
sops.secrets."dotfiles/acoustid_api" = {
  sopsFile = "${sopsFolder}/shared.yaml";
  path = "/run/secrets/acoustid_api";
  owner = "rain";
  mode = "0400";
};
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

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        HOST A (Desktop)                         │
├─────────────────────────────────────────────────────────────────┤
│ 1. Edit dotfiles locally                                        │
│ 2. Auto-upgrade timer triggers (daily at 04:00)                 │
│ 3. chezmoi-pre-update.service:                                  │
│    - jj git fetch                                               │
│    - jj rebase (merge remote changes)                           │
│    - chezmoi re-add (capture local changes)                     │
│    - jj describe (create commit)                                │
│    - jj git push                                                │
│ 4. auto-upgrade.service:                                        │
│    - git pull nix-config                                        │
│    - nh os build (validate)                                     │
│    - nh os switch (deploy)                                      │
│    - git commit & push (if hostCanCommitConfig)                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ├─ GitHub dotfiles repo ─┐
                              ├─ GitHub nix-config ────┤
                              │                         │
┌─────────────────────────────────────────────────────────────────┐
│                         HOST B (Server)                         │
├─────────────────────────────────────────────────────────────────┤
│ 1. Auto-upgrade timer triggers                                  │
│ 2. chezmoi-pre-update.service:                                  │
│    - jj git fetch (gets Host A's changes)                       │
│    - jj rebase (merges as parallel commit if conflict)          │
│    - jj git push (if local changes)                             │
│ 3. auto-upgrade.service:                                        │
│    - git pull nix-config (gets Host A's config)                 │
│    - nh os build (validate)                                     │
│    - nh os switch (deploy)                                      │
│ 4. Boot validation:                                             │
│    - Validates SSH, Tailscale, etc.                             │
│    - If success → pin as golden                                 │
│    - If failure (2x) → rollback to golden                       │
└─────────────────────────────────────────────────────────────────┘
```

## Recovery Procedures

See `docs/recovery-procedures.md`

## Migration Guide

See `docs/migration-guide.md`
