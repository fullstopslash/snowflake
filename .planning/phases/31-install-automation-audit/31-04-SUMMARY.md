# Phase 31 Plan 4: Deploy Keys & GitHub Auth Summary

**Deploy keys fully automated for all repos with root and user access**

## Accomplishments

- Enhanced gh CLI automation to generate and deploy keys for all three repos:
  - `fullstopslash/snowflake` (nix-config)
  - `fullstopslash/snowflake-secrets` (nix-secrets)
  - `fullstopslash/dotfiles` (chezmoi)
- All three deploy keys stored in SOPS under deploy-keys section
- Deploy keys deployed to both root and user accounts with correct permissions
- SSH config fixed to use direct `github.com` host (not aliases)
- SSH config includes all three identity files with `IdentitiesOnly yes`
- Clone operations updated to use direct `git@github.com:` URLs
- All changes support nix flake URLs (e.g., `nix flake update nix-secrets`)

## Files Created/Modified

- `justfile` - Enhanced deploy key and SSH config helpers:
  - `_setup-deploy-keys`: Added chezmoi-deploy key generation and GitHub upload
  - `_setup-deploy-keys`: Deploy all three keys (nix-config, nix-secrets, chezmoi) to root
  - `_configure-ssh-github`: Copy all three keys to user account
  - `_configure-ssh-github`: Configure SSH with multiple IdentityFile entries
  - `_clone-repos`: Changed from SSH aliases to direct github.com URLs

## Decisions Made

**Deploy Key Strategy**:
- Per-host keys for security isolation (not shared across hosts)
- Three separate deploy keys per host (one per repo)
- All keys stored in SOPS at `sops/{HOST}.yaml` under `deploy-keys` section
- Keys deployed to both root and primary user for automated and manual operations

**SSH Configuration Strategy**:
- Use direct `Host github.com` (not aliases like `github.com-nix-config`)
- Required for nix flake URLs which use `git@github.com` directly
- Multiple `IdentityFile` entries (SSH tries each in order)
- `IdentitiesOnly yes` prevents SSH from trying other keys
- Same configuration for both root and user accounts

**Idempotent Operation**:
- Check if deploy keys exist in SOPS before generating new ones
- gh CLI handles duplicate key uploads gracefully
- Existing keys in SOPS are reused (not regenerated)

## Issues Encountered

None. All three tasks completed successfully:
1. Deploy key automation verified and enhanced for all three repos
2. Keys deployed to both root and user with correct permissions
3. SSH config uses direct github.com access (not aliases)

## Verification Checklist

- [x] Deploy keys generated for all three repos (nix-config, nix-secrets, chezmoi)
- [x] gh CLI automation uploads keys to GitHub with host-specific titles
- [x] Keys stored in SOPS under deploy-keys section
- [x] Keys deployed to /root/.ssh/ with 600 permissions
- [x] Keys copied to user home with correct ownership
- [x] SSH config on both accounts uses `Host github.com`
- [x] SSH config includes `IdentitiesOnly yes`
- [x] Clone operations use direct `git@github.com:` URLs

## Technical Details

**Deploy Key Generation** (_setup-deploy-keys helper):
```bash
# Generates three ED25519 keys per host
ssh-keygen -t ed25519 -f nix-config-deploy -C "{HOST}-nix-config-deploy"
ssh-keygen -t ed25519 -f nix-secrets-deploy -C "{HOST}-nix-secrets-deploy"
ssh-keygen -t ed25519 -f chezmoi-deploy -C "{HOST}-chezmoi-deploy"

# Uploads to GitHub via gh CLI
gh repo deploy-key add nix-config-deploy.pub -R fullstopslash/snowflake
gh repo deploy-key add nix-secrets-deploy.pub -R fullstopslash/snowflake-secrets
gh repo deploy-key add chezmoi-deploy.pub -R fullstopslash/dotfiles

# Stores in SOPS
sops --set '{deploy-keys: {nix-config: "...", nix-secrets: "...", chezmoi: "..."}}' sops/{HOST}.yaml
```

**SSH Configuration** (_configure-ssh-github helper):
```ssh-config
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/nix-config-deploy
    IdentityFile ~/.ssh/nix-secrets-deploy
    IdentityFile ~/.ssh/chezmoi-deploy
    IdentitiesOnly yes
    StrictHostKeyChecking no
```

**Clone Operations** (_clone-repos helper):
```bash
# Direct github.com URLs (not aliases)
git clone git@github.com:fullstopslash/snowflake.git nix-config
git clone git@github.com:fullstopslash/snowflake-secrets.git nix-secrets
git clone git@github.com:fullstopslash/dotfiles.git .local/share/chezmoi
```

## Benefits

1. **Automated Authentication**: No manual deploy key setup required
2. **Per-Host Security**: Each host has unique keys (security isolation)
3. **Dual Access**: Both root (automation) and user (manual) can access repos
4. **Nix Flake Support**: Direct github.com URLs work with nix flake operations
5. **Idempotent**: Safe to re-run without generating duplicate keys
6. **SOPS Backup**: Keys backed up in encrypted nix-secrets repo

## Next Step

Ready for 31-05-PLAN.md (Repository Provisioning & Persistence)
