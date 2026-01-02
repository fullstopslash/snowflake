# Chezmoi SSH Setup - Automatic Dotfiles Management

## Overview

Chezmoi is configured to automatically clone and manage dotfiles from the private GitHub repository via SSH on all non-minimal hosts.

## Configuration

### SSH Access (home-manager/chezmoi.nix)

```nix
# 1. Ensure .ssh directory exists
home.file.".ssh/.keep".text = "";

# 2. Symlink SSH private key from SOPS secret
home.file.".ssh/id_ed25519".source =
  config.lib.file.mkOutOfStoreSymlink "/run/secrets/keys/ssh/ed25519";

# 3. Add GitHub SSH host keys to known_hosts
home.file.".ssh/known_hosts".text = ''
  github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5...
  ...
'';
```

### Automatic Initialization

On home-manager activation:
1. Checks if SSH key exists at `~/.ssh/id_ed25519`
2. If chezmoi not initialized: `chezmoi init --apply git@github.com:fullstopslash/dotfiles.git`
3. If already initialized: `chezmoi update`

## How It Works

### Fresh Install Flow

1. **NixOS Install**: System boots with SOPS secrets
   - SSH key deployed to `/run/secrets/keys/ssh/ed25519`

2. **Home-Manager Activation**: (runs during `nixos-rebuild` or user login)
   - Creates `.ssh` directory (via `.keep` file)
   - Creates symlink: `~/.ssh/id_ed25519 -> /run/secrets/keys/ssh/ed25519`
   - Creates `~/.ssh/known_hosts` with GitHub keys

3. **Chezmoi Activation**: (runs after home-manager)
   - Verifies SSH key exists
   - Clones `git@github.com:fullstopslash/dotfiles.git` to `~/.local/share/chezmoi`
   - Applies dotfiles to home directory

### Subsequent Rebuilds

- Chezmoi automatically updates: `chezmoi update`
- Pulls latest changes from GitHub
- Re-applies templates

## SSH vs HTTPS

✅ **SSH (Current)**:
- Uses private key from SOPS
- Secure, encrypted authentication
- No password/token needed
- Works automatically after SOPS deployment

❌ **HTTPS (Old)**:
- Requires GitHub token
- Token management complexity
- Less secure for private repos

## Troubleshooting

### Chezmoi Not Initialized

If chezmoi fails during activation:

```bash
# Check SSH key
ls -la ~/.ssh/id_ed25519
# Should be symlink to /run/secrets/keys/ssh/ed25519

# Manually initialize
chezmoi init --apply git@github.com:fullstopslash/dotfiles.git
```

### Template Errors

Chezmoi templates may reference secrets from `/run/secrets/*`:

```bash
# Example error:
# template: ... error calling include: open /run/secrets/acoustid_api: no such file or directory
```

**Solution**: Ensure all required secrets are defined in `sops/<hostname>.yaml` and deployed via SOPS.

### SSH Authentication Failed

```bash
# Test SSH access to GitHub
ssh -T git@github.com
# Should show: "Hi fullstopslash! You've successfully authenticated..."

# Check key permissions
ls -la ~/.ssh/id_ed25519  # Should be 600 or symlink
cat /run/secrets/keys/ssh/ed25519  # Should contain private key
```

## Manual Operations

### Re-add Changed Files

When you modify dotfiles directly:

```bash
# Capture changes back to chezmoi
chezmoi re-add ~/.config/hyprland/hyprland.conf

# Review changes
chezmoi diff

# Commit and push
cd ~/.local/share/chezmoi
git add .
git commit -m "Update hyprland config"
git push
```

### Force Re-initialization

```bash
# Remove chezmoi state
rm -rf ~/.local/share/chezmoi

# Re-initialize
chezmoi init --apply git@github.com:fullstopslash/dotfiles.git
```

## Integration with Auto-Upgrade

Chezmoi automatically updates during:
- System rebuilds (`nixos-rebuild`)
- Home-manager activations
- Manual `chezmoi update`

Dotfiles stay in sync across all hosts without manual intervention.
