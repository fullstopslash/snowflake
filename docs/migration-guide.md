# Migration Guide: Decentralized GitOps Setup

Guide for adopting this multi-host NixOS + chezmoi GitOps architecture.

## Prerequisites

- NixOS hosts with SSH access
- Git repository for nix-config
- Git repository for dotfiles (chezmoi)
- SOPS configured with age/SSH keys

## Step 1: Enable SOPS Secrets (if not already)

See Phase 4 documentation.

Verify SOPS is working:
```bash
# Check age keys exist
ls -la ~/.config/sops/age/keys.txt

# Test decryption
cd ~/nix-secrets
sops -d sops/shared.yaml
```

## Step 2: Enable Golden Generation Rollback

In role or host config:
```nix
myModules.system.boot.goldenGeneration = {
  enable = true;
  validateServices = [ "sshd.service" ];  # Add host-specific services
  autoPinAfterBoot = true;
};
```

Deploy:
```bash
nh os switch
reboot  # Verify boot validation works
show-boot-status  # Check golden generation is pinned
```

## Step 3: Enable Auto-Upgrade Module

In role or host config:
```nix
myModules.services.system.autoUpgrade = {
  enable = true;
  mode = "local";  # or "remote" for direct flake pulls
  schedule = "04:00";  # Daily at 4 AM
  buildBeforeSwitch = true;  # Validate before deploying
  validationChecks = [
    "systemctl --quiet is-enabled sshd"
    # Add host-specific validation commands
  ];
};
```

Deploy and test:
```bash
nh os switch
# Manually trigger to test
sudo systemctl start auto-upgrade.service
# Watch logs
journalctl -u auto-upgrade.service -f
```

## Step 4: Migrate Chezmoi Secrets to SOPS

### 4.1 Audit chezmoi templates

```bash
cd ~/.local/share/chezmoi

# Find all template files
find . -type f -name "*.tmpl" -o -name ".chezmoi*"

# Search for template variables
grep -r "{{" . | grep -v ".git"

# Identify secrets vs non-secrets
# Secrets: API keys, tokens, passwords, private emails
# Non-secrets: Public emails, name, desktop environment
```

### 4.2 Add secrets to SOPS

```bash
cd ~/nix-secrets

# Add secret to SOPS using --set
sops --set '["dotfiles"]["my_api_key"] "secret-value"' sops/shared.yaml

# Verify
sops -d sops/shared.yaml | grep -A2 "dotfiles:"

# Commit
git add sops/shared.yaml
git commit -m "feat(secrets): add dotfiles secrets"
git push
```

### 4.3 Configure SOPS secret in NixOS

In `modules/services/dotfiles/chezmoi-sync.nix` or host config:
```nix
sops.secrets."dotfiles/my_api_key" = {
  sopsFile = "${sopsFolder}/shared.yaml";
  path = "/run/secrets/my_api_key";
  owner = config.users.users.rain.name;
  mode = "0400";
};
```

### 4.4 Update chezmoi templates

**Before:**
```bash
# template.tmpl
api_key = "{{ .my_api_key }}"
```

**After:**
```bash
# template.tmpl
api_key = "{{ include "/run/secrets/my_api_key" | trim }}"
```

### 4.5 Remove secrets from chezmoi data files

```bash
# Remove from .chezmoidata.yaml or .chezmoi.toml
# Keep only non-secret config (name, email, etc.)
```

### 4.6 Test

```bash
# Rebuild to create secret files
nh os switch

# Verify secret exists
ls -la /run/secrets/my_api_key

# Test template rendering
chezmoi apply --dry-run --verbose
```

## Step 5: Enable Chezmoi Sync Module

In role or host config:
```nix
# Enable hasSecrets if not already
hostSpec.hasSecrets = true;

# Configure chezmoi sync
myModules.services.dotfiles.chezmoiSync = {
  enable = true;
  repoUrl = "git@github.com:user/dotfiles.git";
  syncBeforeUpdate = true;
  autoCommit = true;
  autoPush = true;
};

# Hook into auto-upgrade
myModules.services.system.autoUpgrade.preUpdateHooks = [
  "chezmoi-pre-update.service"
];
```

Deploy:
```bash
nh os switch
```

## Step 6: Initialize Chezmoi with jj

On each host:

```bash
# 1. Initialize chezmoi (if not already)
chezmoi init git@github.com:user/dotfiles.git

# 2. Convert to jj co-located repo
cd ~/.local/share/chezmoi
jj git init --colocate

# 3. Check status
jj status
jj log --limit 5

# 4. Capture current state
chezmoi re-add

# 5. Create initial commit
jj describe -m "chore($(hostname)): initial jj setup - $(date -Iseconds)"

# 6. Create bookmark and push
jj bookmark create $(hostname)-init
jj git push --allow-new

# 7. Verify
jj log --limit 3
chezmoi-status
```

## Step 7: Test End-to-End

### Test 1: Dotfile Change

```bash
# Make a change
echo "# Test change $(date)" >> ~/.bashrc

# Wait for auto-upgrade or trigger manually
sudo systemctl start auto-upgrade.service

# Check logs
journalctl -u chezmoi-pre-update.service | tail -20

# Verify pushed
cd ~/.local/share/chezmoi
jj log --limit 3
```

### Test 2: Build Validation

```bash
# Introduce syntax error
cd /home/rain/nix-config
echo "invalid { syntax" >> hosts/$(hostname)/default.nix

# Commit and push
git add .
git commit -m "test: intentional build error"
git push

# Wait for auto-upgrade
sudo systemctl start auto-upgrade.service

# Should see validation failure
journalctl -u auto-upgrade.service | grep "Build Validation"

# Fix
git revert HEAD
git push
```

### Test 3: Boot Validation

```bash
# Check boot status
show-boot-status

# Should show:
# - Golden generation pinned
# - Boot failure count: 0
# - Boot status: Validated
```

## Step 8: Multi-Host Setup

Repeat Steps 5-7 on each host.

**Important:**
- Each host will have its own jj bookmark (e.g., `desktop-init`, `server-init`)
- Concurrent edits will create parallel commits (handled by jj)
- Hosts will eventually converge on the same state

## Step 9: Monitor and Iterate

### Check Sync Status

```bash
# Dotfile sync
chezmoi-status
cat /var/lib/chezmoi-sync/last-sync-status

# Auto-upgrade
systemctl status auto-upgrade.service
journalctl -u auto-upgrade.service --since today

# Boot validation
show-boot-status
```

### Adjust Timing

If needed, adjust timer schedules:
```nix
# In host config
myModules.services.system.autoUpgrade.schedule = "hourly";
# or
myModules.services.system.autoUpgrade.schedule = "*-*-* 04:00:00";
```

### Add Validation Checks

Add host-specific validation:
```nix
myModules.services.system.autoUpgrade.validationChecks = [
  "systemctl --quiet is-enabled sshd"
  "systemctl --quiet is-active tailscaled"
  "test -f /etc/nixos/configuration.nix"
];

myModules.system.boot.goldenGeneration.validateServices = [
  "sshd.service"
  "tailscaled.service"
  "networkmanager.service"
];
```

## Troubleshooting

See `docs/recovery-procedures.md` for common issues and solutions.

## Rollback Plan

If migration causes issues:

1. **Disable chezmoi sync:**
   ```nix
   myModules.services.dotfiles.chezmoiSync.enable = false;
   ```

2. **Disable build validation:**
   ```nix
   myModules.services.system.autoUpgrade.buildBeforeSwitch = false;
   ```

3. **Disable auto-upgrade:**
   ```nix
   myModules.services.system.autoUpgrade.enable = false;
   ```

4. **Manual operations:**
   - Use chezmoi manually without automation
   - Deploy NixOS changes manually with `nh os switch`

## Next Steps

After successful migration:

- **Monitor**: Check logs daily for first week
- **Tune**: Adjust timing, validation checks based on usage
- **Document**: Add host-specific notes to host README
- **Expand**: Consider adding more hosts to the setup

## Security Considerations

1. **Secret Rotation**: After migration, rotate any secrets that may have been in git
2. **History Cleaning**: Use BFG or filter-branch if secrets were in git history
3. **Access Control**: Ensure only authorized hosts have push access
4. **Audit Trail**: All changes logged in git history (chezmoi + nix-config)
5. **SOPS Keys**: Securely backup age keys, store in password manager
