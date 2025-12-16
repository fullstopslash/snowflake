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
jj git push --allow-new

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

## JJ Conflicts Not Resolving

**Symptoms**: jj log shows conflicts that aren't being reconciled

**Recovery**:
```bash
cd ~/.local/share/chezmoi

# View conflicts
jj log --conflicts --limit 10

# Interactive conflict resolution
jj resolve

# After resolution, describe and push
jj describe -m "fix: reconcile conflicts"
jj git push --allow-new
```

## SOPS Decryption Failures

**Symptoms**: Secrets not decrypting at boot, services failing

**Recovery**:
```bash
# Check SOPS can decrypt
cd ~/nix-secrets
sops -d sops/shared.yaml

# Verify age key exists
ls -la ~/.config/sops/age/keys.txt

# Check secret paths in NixOS config
nixos-rebuild dry-build --show-trace

# If key is missing, regenerate from SOPS
# (see docs/sops-rotation.md)
```

## Network Failure During Auto-Upgrade

**Symptoms**: Auto-upgrade fails due to network issues

**Recovery**:
```bash
# Check network
ping -c 3 github.com

# Check last sync status
cat /var/lib/chezmoi-sync/last-sync-status

# If network is restored, manually trigger
sudo systemctl start auto-upgrade.service

# Verify
journalctl -u auto-upgrade.service -f
```

## Chezmoi Template Rendering Errors

**Symptoms**: chezmoi apply fails with template errors

**Recovery**:
```bash
# Test template rendering in dry-run mode
chezmoi apply --dry-run --verbose

# Check for missing variables
chezmoi data | jq .

# Check for missing SOPS secrets
ls -la /run/secrets/

# If secret missing, rebuild NixOS config
nh os switch
```

## Golden Generation Missing

**Symptoms**: No golden generation pinned, rollback not possible

**Recovery**:
```bash
# Check current generation status
nixos-rebuild list-generations

# Pin current generation as golden
pin-golden

# Verify
show-golden
show-boot-status
```

## Emergency: Complete System Failure

**Last Resort Recovery**:

1. **Boot from NixOS installation media**
2. **Mount the system:**
   ```bash
   mount /dev/vda1 /mnt
   mount -o subvol=nix,compress=zstd /dev/vda2 /mnt/nix
   ```
3. **Enter nix-shell:**
   ```bash
   nixos-enter --root /mnt
   ```
4. **Rollback to previous generation:**
   ```bash
   nix-env --list-generations --profile /nix/var/nix/profiles/system
   nix-env --rollback --profile /nix/var/nix/profiles/system
   /nix/var/nix/profiles/system/bin/switch-to-configuration boot
   ```
5. **Reboot:**
   ```bash
   reboot
   ```
