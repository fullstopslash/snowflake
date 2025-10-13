# Griefling NH Usage

## Setup Complete! ✅

SSH key copied and configured for GitHub access.

## Available Commands

### Update and Rebuild (Most Common)
```bash
ssh -p 22221 rain@127.0.0.1
nh os switch --update
```

This will:
1. Pull latest changes from GitHub
2. Update all flake inputs
3. Build the new configuration
4. Switch to it

### Other Useful Commands

```bash
# Just rebuild (no git update)
nh os switch

# Test without activating
nh os test --update

# See what would change (dry run)
nh os switch --update --dry

# Clean old generations
nh clean all --keep 5
```

## Environment

- **FLAKE**: `/home/rain/src/nix/nix-config`
- **SSH Port**: 22221
- **User**: rain
- **GitHub**: fullstopslash/snowflake

## SSH Config Override

Added to `~/.ssh/config.d/github-override`:
```
Host github.com
  IdentityFile ~/.ssh/id_ed25519
```

This allows git to authenticate with the copied SSH key.

## Workflow

1. Make changes on your main machine
2. Commit and push to GitHub
3. On griefling: `nh os switch --update`
4. Done! ✨

