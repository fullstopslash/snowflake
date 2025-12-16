# SOPS Key Rotation Guide

## Overview

This guide covers manual SOPS/age key rotation with zero downtime. The process ensures secrets remain accessible during rotation by temporarily encrypting with both old and new keys.

## When to Rotate

Key rotation policy (recommendations):
- **Production servers**: Every 90 days
- **Development hosts**: Every 180 days
- **VMs/testing**: On rebuild (ephemeral)
- **Compromise**: Immediately

Check key age:
```bash
just sops-check-key-age
```

## Rotation Process

### Automated (Recommended)

```bash
# Interactive rotation with verification
just sops-rotate hostname
```

This runs all 7 steps with verification at each stage.

### Manual Step-by-Step

If automated rotation fails or you need more control:

1. **Generate new key**:
   ```bash
   ssh hostname "age-keygen -o /tmp/new-age-key.txt"
   NEW_PUBKEY=$(ssh hostname "age-keygen -y /tmp/new-age-key.txt")
   echo $NEW_PUBKEY
   ```

2. **Add to .sops.yaml** (keep old key):
   ```bash
   cd ../nix-secrets
   # Edit .sops.yaml, add new key with &hostname_new anchor
   # Add to creation_rules for shared.yaml and hostname.yaml
   ```

3. **Rekey with both keys**:
   ```bash
   just rekey
   ```

4. **Deploy new key**:
   ```bash
   ssh hostname "sudo cp /var/lib/sops-nix/key.txt /var/lib/sops-nix/key.txt.old"
   cat /tmp/new-age-key.txt | ssh hostname "sudo tee /var/lib/sops-nix/key.txt"
   ssh hostname "sudo chmod 600 /var/lib/sops-nix/key.txt"
   ```

5. **Verify**:
   ```bash
   ssh hostname "sudo nixos-rebuild test"
   ssh hostname "systemctl status sops-nix.service"
   ssh hostname "sudo ls /run/secrets/"
   ```

6. **Remove old key** from .sops.yaml:
   ```bash
   cd ../nix-secrets
   # Edit .sops.yaml
   # Remove old &hostname line
   # Rename &hostname_new to &hostname
   ```

7. **Final rekey**:
   ```bash
   just rekey
   ```

8. **Update metadata**:
   ```bash
   sops -e -i --set '["sops"]["key-metadata"]["rotated_at"]' '"$(date +%Y-%m-%d)"' ../nix-secrets/sops/hostname.yaml
   ```

## Rollback

If verification fails after deploying new key:

```bash
ssh hostname "sudo mv /var/lib/sops-nix/key.txt.old /var/lib/sops-nix/key.txt"
ssh hostname "sudo nixos-rebuild test"
```

## Future: Automated Rotation

Scheduled rotation via systemd timer is planned but not yet implemented.
See `.planning/phases/17-sops-automation/` (future work).
