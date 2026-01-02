# Per-Host Deploy Keys - Secure SSH Access Architecture

## Overview

Each host has unique GitHub deploy keys stored in its own SOPS file (`sops/<hostname>.yaml`). This provides:
- **Per-host access control**: Revoke access for compromised hosts without affecting others
- **Audit trail**: Track which host accessed which repo
- **Defense in depth**: Each host has minimal required permissions
- **Read-only access**: Deploy keys can only pull, not push

## Architecture

### Deploy Key Generation (During `just vm-fresh`)

1. **Check existing keys**: Script checks if `deploy-keys` already exist in `sops/<hostname>.yaml`
2. **Generate unique keys**: If not found, generates two ED25519 deploy keys:
   - `<hostname>-nix-config-deploy`: For cloning nix-config repo
   - `<hostname>-nix-secrets-deploy`: For cloning nix-secrets repo
3. **GitHub registration**: User adds public keys to GitHub repos (read-only)
4. **SOPS storage**: Private keys stored encrypted in `sops/<hostname>.yaml`:
   ```yaml
   deploy-keys:
     nix-config: |
       -----BEGIN OPENSSH PRIVATE KEY-----
       ...
     nix-secrets: |
       -----BEGIN OPENSSH PRIVATE KEY-----
       ...
   ```

### Deployment to Host

1. **Extract from SOPS**: Private keys extracted from host-specific SOPS file
2. **Deploy to VM**: Keys copied to `/root/.ssh/` on target host
3. **SSH config**: Creates aliases for each repo:
   ```ssh-config
   Host github.com-nix-config
       HostName github.com
       User git
       IdentityFile ~/.ssh/nix-config-deploy

   Host github.com-nix-secrets
       HostName github.com
       User git
       IdentityFile ~/.ssh/nix-secrets-deploy
   ```
4. **Clone repos**: Uses SSH aliases:
   ```bash
   git clone git@github.com-nix-config:fullstopslash/snowflake.git
   git clone git@github.com-nix-secrets:fullstopslash/snowflake-secrets.git
   ```

## Security Benefits

### Isolation
- Each host has unique keys
- Compromising one host doesn't compromise others
- Can revoke per-host without affecting fleet

### Least Privilege
- Deploy keys are **read-only**
- Can't push changes to repos
- Limited to specific repos

### Encrypted at Rest
- Private keys stored in SOPS (encrypted)
- Only decryptable by authorized age keys
- Protected even if nix-secrets repo is leaked

### Audit Trail
- GitHub shows which deploy key accessed repo
- Can correlate with hostname via key comment
- Track suspicious access patterns

## Operations

### Adding a New Host

1. Run `just vm-fresh <hostname>`
2. Script generates deploy keys
3. Add public keys to GitHub:
   - Go to repo Settings → Deploy keys
   - Add key with descriptive name (e.g., "griefling-deploy")
   - Check "Allow read access" only
4. Press Enter to continue automation

### Revoking Access

If a host is compromised:
1. Go to GitHub repo Settings → Deploy keys
2. Remove the host's deploy key
3. Host can no longer clone/pull repos
4. Other hosts unaffected

### Rotating Keys

To rotate a host's deploy keys:
```bash
# 1. Remove old keys from SOPS
cd ../nix-secrets
sops sops/<hostname>.yaml  # Delete deploy-keys section

# 2. Re-run vm-fresh (will generate new keys)
cd ../nix-config
just vm-fresh <hostname>

# 3. Remove old deploy keys from GitHub
# 4. Add new public keys to GitHub
```

## Comparison to Shared Key Approach

| Aspect | Shared Key (Old) | Per-Host Deploy Keys (New) |
|--------|-----------------|----------------------------|
| Security | ❌ One key compromises all | ✅ Per-host isolation |
| Revocation | ❌ Affects all hosts | ✅ Per-host granular |
| Audit | ❌ Can't distinguish hosts | ✅ Clear per-host trail |
| Permissions | ❌ Read/write access | ✅ Read-only |
| Storage | ❌ shared.yaml | ✅ <hostname>.yaml |

## Future Enhancements

- [ ] Automate GitHub deploy key registration via API
- [ ] Periodic key rotation (e.g., every 90 days)
- [ ] Monitor deploy key usage via GitHub API
- [ ] Alert on suspicious access patterns
- [ ] Support for host key rotation (migrate from deploy keys to host SSH keys)
