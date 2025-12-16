# DEVICE STOLEN - QUICK REFERENCE CARD

**PRINT THIS PAGE AND KEEP IT ACCESSIBLE OFFLINE**

---

## IMMEDIATE ACTION (0-15 min)

### 1. CONFIRM THEFT
- [ ] Search thoroughly (not misplaced?)
- [ ] Document: hostname, time, location
- [ ] Identify what secrets device had

### 2. ISOLATE DEVICE
```bash
# Disable from Tailscale (from another device)
tailscale logout --remote [stolen-device-name]

# Or via: https://login.tailscale.com/admin/machines
# Find device → Disable
```

### 3. GATHER INFO
```bash
# Get age key fingerprint
cd nix-secrets
grep -A 1 "&[hostname]" .sops.yaml

# List compromised secrets
sops -d sops/[hostname].yaml | grep -v "^sops:"
```

---

## KEY ROTATION (15-60 min)

### 1. REMOVE STOLEN KEY
```bash
cd nix-secrets
cp .sops.yaml .sops.yaml.backup

# Edit .sops.yaml
nano .sops.yaml

# Remove these lines:
# - &[stolen-hostname] age1...
# - All *[stolen-hostname] references in creation_rules

git add .sops.yaml
git commit -m "chore: remove compromised key for [hostname]"
git push
```

### 2. REKEY ALL SECRETS
```bash
cd ../nix-config
just rekey

# This will:
# - Rekey all sops/*.yaml files
# - Commit changes
# - Push to remote
```

### 3. VERIFY
```bash
# Check stolen key removed
grep "[stolen-hostname]" nix-secrets/.sops.yaml
# Should return nothing

# Test another host can still decrypt
ssh [other-host] "sudo nixos-rebuild dry-run --flake ~/nix-config"
ssh [other-host] "systemctl status sops-nix.service"
```

### 4. DEPLOY TO ALL HOSTS
```bash
# Wait for auto-update OR manually trigger:
for host in host1 host2 host3; do
  ssh $host "cd ~/nix-config && git pull && sudo nixos-rebuild switch --flake .#$host"
done
```

---

## SECRET ROTATION (1-4h)

**PRIORITY ORDER**:

### 1. Tailscale Auth Keys (1h - CRITICAL)
```bash
# Revoke: https://login.tailscale.com/admin/settings/keys
# Generate new key → Update in nix-secrets/sops/shared.yaml
cd nix-secrets
sops sops/shared.yaml
# Update tailscale_auth_key
cd ../nix-config && just rekey
```

### 2. API Tokens (2h - HIGH)
- GitHub: https://github.com/settings/tokens
- Cloud providers (AWS, GCP, Azure)
- Service APIs (Stripe, etc.)

For each:
1. Revoke old token via provider
2. Generate new token
3. Update in `nix-secrets/sops/[hostname].yaml`
4. Rekey and deploy

### 3. Database Passwords (2h - HIGH)
```bash
# PostgreSQL
ssh [db-host] "sudo -u postgres psql"
ALTER USER dbuser WITH PASSWORD 'new-password';

# Update in nix-secrets
sops sops/[hostname].yaml
# Update password field
```

### 4. SSH Keys (4h - MEDIUM)
```bash
# Generate new key
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_new

# Copy to authorized_keys on all targets
ssh-copy-id -i ~/.ssh/id_ed25519_new.pub user@remote

# Update in nix-secrets
# Remove old key from remote authorized_keys
```

### 5. Service Passwords (4h - MEDIUM)
- Admin passwords (Grafana, Nextcloud, etc.)
- Service account passwords
- Application credentials

---

## MONITORING (0-7 days)

### Immediate (every 15 min for 4h)
```bash
# Check Tailscale
tailscale status

# Check SSH logs
ssh [host] "sudo journalctl -u sshd --since '1 hour ago'"

# Check failed auths
ssh [host] "sudo journalctl | grep -i 'failed password' --since '1 hour ago'"
```

### Daily (for 7 days)
```bash
# GitHub security log
# Visit: https://github.com/settings/security-log

# Check each host
for host in host1 host2 host3; do
  echo "=== $host ==="
  ssh $host "last | head -10"
done
```

**Watch for**:
- Stolen device coming online
- New unexpected devices
- Failed auth attempts
- Unusual API calls
- Unexpected rebuilds
- New SSH connections

---

## RESPONSE TIME TARGETS

| Action | Target |
|--------|--------|
| Notice theft | < 30 min |
| Begin response | < 15 min |
| Key rotation | < 1 hour |
| Critical secrets (Tailscale, APIs) | < 2 hours |
| All secrets | < 4 hours |
| Monitoring | 7 days |

---

## FULL RUNBOOK

**Complete procedures**: `docs/incident-response/device-stolen.md`

**Rotation details**: `docs/sops-rotation.md`

**Commands**:
- `just rekey` - Rekey all secrets
- `just sops-rotate [host]` - Interactive rotation
- `just sops-check-key-age` - Check key ages

---

## EMERGENCY CONTACTS

**Primary**: `_____________________________`

**Backup**: `_____________________________`

**Support**: `_____________________________`

---

## POST-INCIDENT (T+7d)

- [ ] Complete timeline reconstruction
- [ ] Assess impact (what was accessed?)
- [ ] Review what worked / didn't work
- [ ] Create incident report in `incident-reports/`
- [ ] Update runbooks based on findings
- [ ] Implement improvements (LUKS, monitoring, etc.)

**Incident report template**: See full runbook section "Phase 5: Post-Incident Review"

---

## PREVENTION (FUTURE)

**This is damage control - prevention is better:**

- [ ] Enable LUKS disk encryption (Plan 17-01)
- [ ] Implement regular key rotation
- [ ] Add monitoring/alerting
- [ ] Reduce secret count
- [ ] Test quarterly rotation drills

---

**Print Date**: _______________

**Last Tested**: _______________

**Next Test Due**: _______________

---

**VERSION**: 1.0 | **CREATED**: 2025-12-16 | **PHASE**: 17-02
