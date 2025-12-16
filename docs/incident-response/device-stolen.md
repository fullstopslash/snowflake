# Device Stolen Incident Response Runbook

**STATUS**: FUTURE WORK - Review before deployment
**PRIORITY**: CRITICAL - Device theft requires immediate action
**RESPONSE TIME TARGET**: < 1 hour for key rotation

## Overview

This runbook provides step-by-step procedures to respond to physical device compromise (theft, loss, confiscation). The goal is to minimize damage, rotate credentials, and restore security after a device containing SOPS/age keys is stolen.

**IMPORTANT**: This runbook assumes the attacker can extract `/var/lib/sops-nix/key.txt` and decrypt ALL historical secrets encrypted for that key. New secrets created post-rotation are safe.

## Threat Model

**Attack Scenario**:
1. Attacker steals physical device (laptop, desktop)
2. Attacker extracts `/var/lib/sops-nix/key.txt` (age private key)
3. Attacker clones `nix-secrets` repo from GitHub
4. Attacker can decrypt ALL historical secrets encrypted for that key
5. New secrets (post-rotation) are safe

**Attack Timeline**:
```
T+0:     Device stolen, attacker extracts age key
T+1h:    You notice theft, begin response
T+2h:    Attacker clones nix-secrets, decrypts all secrets
T+4h:    You complete key rotation, new secrets encrypted
Result:  Old secrets exposed, new secrets safe, services disrupted
```

**Response Goals**:
1. Minimize exposure window (< 1 hour response time)
2. Rotate all compromised credentials
3. Revoke device access to infrastructure
4. Monitor for unauthorized access
5. Restore secure operations

## Response Timeline

| Phase | Duration | Actions |
|-------|----------|---------|
| Immediate Response | T+0 to T+15min | Confirm theft, isolate device, alert team |
| Key Rotation | T+15min to T+1h | Remove compromised key, rekey all secrets |
| Secret Rotation | T+1h to T+4h | Rotate credentials by priority |
| Monitoring | T+0 to T+7d | Watch for unauthorized access |
| Post-Incident | T+7d | Review, lessons learned, improvements |

---

## PHASE 1: IMMEDIATE RESPONSE (T+0 to T+15min)

### Step 1: Confirm Theft (0-5 min)

**DO NOT PANIC**. Verify the device is actually stolen, not just misplaced.

1. **Search thoroughly**:
   - Check last known location
   - Check other bags, rooms
   - Ask family/colleagues if they've seen it
   - Check "Find My Device" services if enabled

2. **Identify the device**:
   - Hostname: `____________`
   - Physical location when stolen: `____________`
   - Date/time of theft: `____________`
   - Circumstances: `____________`

3. **Determine device role** (from `flake.nix` or memory):
   - Desktop? Laptop? Server? VM?
   - What services were running?
   - What secrets did it have access to?

4. **Document everything**:
   - Write down timeline
   - Note what you remember
   - Take photos of location (for insurance/police)

### Step 2: Immediate Network Isolation (5-10 min)

**Goal**: Prevent attacker from using device to access infrastructure.

1. **Disable Tailscale access**:
   ```bash
   # From another device with Tailscale admin access
   tailscale logout --remote [stolen-device-name]

   # Or via admin console: https://login.tailscale.com/admin/machines
   # Find device → Menu → Disable
   ```

2. **Check if device is online**:
   ```bash
   # From another device
   tailscale status | grep [stolen-device-name]
   ping [stolen-device-ip]

   # If online, monitor activity BEFORE disabling
   # This may provide evidence of attacker actions
   ```

3. **Revoke SSH access** (if device had SSH keys to other hosts):
   ```bash
   # SSH to each host the stolen device could access
   # Remove its public key from authorized_keys

   ssh [other-host] "sudo nano /home/rain/.ssh/authorized_keys"
   # Delete line with stolen device's key
   ```

4. **Monitor for immediate activity**:
   - Check Tailscale activity logs
   - Check SSH logs on other hosts
   - Look for unexpected connections

### Step 3: Alert Team/Family (10-15 min)

**If multiple people have secrets access or manage infrastructure:**

1. **Notify others immediately**:
   - Explain situation clearly
   - Provide device hostname
   - Share this runbook link
   - Coordinate response actions

2. **Assign tasks** (if multiple people available):
   - Person A: Key rotation
   - Person B: Secret rotation
   - Person C: Monitoring
   - Person D: Documentation

3. **Communication channel**:
   - Use secure channel (Signal, Element, etc.)
   - Do NOT use compromised services
   - Keep channel open for coordination

### Step 4: Gather Device Information (10-15 min)

**Collect information needed for key rotation:**

1. **Get device hostname**:
   - From memory or documentation
   - Check Tailscale admin console
   - Check GitHub Actions logs (if auto-update enabled)

2. **Get age key fingerprint**:
   ```bash
   # From another device
   cd nix-secrets
   grep -A 1 "&[stolen-hostname]" .sops.yaml
   # Copy the age1... public key
   ```

3. **List secrets encrypted for this key**:
   ```bash
   cd nix-secrets
   # Check which secrets use this key in creation_rules
   cat .sops.yaml | grep -A 10 "path_regex.*[stolen-hostname]"

   # List all secrets that might be compromised
   ls sops/[stolen-hostname].yaml
   sops -d sops/[stolen-hostname].yaml | grep -v "^sops:"
   ```

4. **Identify critical services**:
   - Database passwords
   - API tokens
   - SSH keys
   - Service credentials
   - Tailscale auth keys

**CHECKLIST**:
- [ ] Theft confirmed (not misplaced)
- [ ] Device hostname identified: `____________`
- [ ] Age key fingerprint: `age1____________`
- [ ] Device disabled from Tailscale
- [ ] SSH access revoked (if applicable)
- [ ] Team/family alerted (if applicable)
- [ ] Secret inventory completed
- [ ] Ready to begin key rotation

---

## PHASE 2: KEY ROTATION (T+15min to T+1h)

**Goal**: Remove compromised age key and rekey all secrets so attacker cannot decrypt new secrets.

### Overview

The key rotation process:
1. Remove compromised key from `.sops.yaml`
2. Rekey all secrets (existing secrets remain encrypted with remaining keys)
3. Verify rekeying succeeded
4. Deploy to all remaining hosts

**IMPORTANT**: This uses the rotation infrastructure from Phase 16-03.

### Step 1: Remove Compromised Key from .sops.yaml (15-20 min)

```bash
cd nix-secrets

# Backup current config
cp .sops.yaml .sops.yaml.backup

# Edit .sops.yaml manually
sops .sops.yaml
# OR use editor of choice:
nano .sops.yaml
```

**What to remove:**
1. Find the `keys.hosts` section
2. Locate the line with `&[stolen-hostname]` anchor
3. Delete that line AND the following line (the age public key)
4. Find all references in `creation_rules`
5. Remove `*[stolen-hostname]` from all `key_groups`

**Example**:
```yaml
# BEFORE (remove these lines):
keys:
  hosts:
    - &griefling age1abcdefg...xyz123

creation_rules:
  - path_regex: sops/griefling\.yaml$
    key_groups:
      - age:
        - *rain_griefling
        - *griefling          # <- REMOVE THIS

# AFTER:
keys:
  hosts:
    # griefling key removed

creation_rules:
  - path_regex: sops/griefling\.yaml$
    key_groups:
      - age:
        - *rain_griefling
        # griefling key removed
```

**Verify changes**:
```bash
# Check syntax is still valid
cat .sops.yaml | yq '.'

# Commit changes
cd nix-secrets
git add .sops.yaml
git commit -m "chore: remove compromised key for [stolen-hostname]"
git push
```

### Step 2: Rekey All Secrets (20-40 min)

```bash
cd nix-config

# Run rekey command (uses existing rotation infrastructure)
just rekey

# This will:
# 1. Run sops updatekeys on all sops/*.yaml files
# 2. Re-encrypt with remaining keys (stolen key removed)
# 3. Run pre-commit hooks
# 4. Commit changes
# 5. Push to remote
```

**Expected output**:
```
Rekeying sops/shared.yaml...
Rekeying sops/[hostname].yaml...
...
Running pre-commit hooks...
Committing changes...
Pushing to remote...
```

**If rekey fails**:
- Check .sops.yaml syntax
- Ensure at least one valid key remains in each creation_rule
- Check that sops binary is working
- See `docs/sops-rotation.md` for troubleshooting

### Step 3: Verify Rekeying (40-45 min)

```bash
cd nix-secrets

# Test that stolen key can NO LONGER decrypt
# (You can't actually test this without the private key, but verify key was removed)
grep "[stolen-hostname]" .sops.yaml
# Should return NO results

# Check that remaining hosts CAN still decrypt
# Test on one active host
ssh [other-host] "sudo nixos-rebuild dry-run --flake ~/nix-config"

# Should succeed without errors
# Check sops-nix service
ssh [other-host] "systemctl status sops-nix.service"
# Should be active

# Verify secrets are still accessible
ssh [other-host] "sudo ls -la /run/secrets/"
# Should show all expected secrets
```

**Verification checklist**:
- [ ] Stolen key removed from .sops.yaml
- [ ] All secrets rekeyed successfully
- [ ] Changes committed and pushed
- [ ] At least one other host can still decrypt secrets
- [ ] sops-nix service active on test host

### Step 4: Deploy to All Hosts (45-60 min)

**Option A: Automatic (if auto-update enabled)**:
```bash
# Auto-update system will pull changes within next update cycle
# Check status:
ssh [host] "systemctl status auto-upgrade.service"
ssh [host] "journalctl -u auto-upgrade.service -n 50"

# Wait for next update (default: every 6 hours)
# Or manually trigger:
ssh [host] "sudo systemctl start auto-upgrade.service"
```

**Option B: Manual deployment**:
```bash
# Deploy to each host individually
for host in host1 host2 host3; do
  echo "Deploying to $host..."
  ssh $host "cd ~/nix-config && git pull && sudo nixos-rebuild switch --flake .#$host"
done

# Or use parallel deployment
parallel -j4 ssh {} "cd ~/nix-config && git pull && sudo nixos-rebuild switch --flake .#{}" ::: host1 host2 host3
```

**Verify each host**:
```bash
for host in host1 host2 host3; do
  echo "Checking $host..."
  ssh $host "systemctl is-active sops-nix.service"
  ssh $host "sudo ls /run/secrets/ | wc -l"
done
```

**CHECKLIST**:
- [ ] Compromised key removed from .sops.yaml
- [ ] All secrets rekeyed successfully
- [ ] Rekeying verified on test host
- [ ] All remaining hosts deployed with new keys
- [ ] All hosts can decrypt secrets
- [ ] Stolen device can no longer decrypt new secrets

---

## PHASE 3: SECRET ROTATION (T+1h to T+4h)

**Goal**: Rotate all credentials that were encrypted with compromised key.

**IMPORTANT**: Even though the key is removed from future secrets, the attacker may have already decrypted historical secrets. ALL credentials must be rotated.

### Priority Matrix

| Secret Type | Priority | Rotation Target | Exposure Impact |
|-------------|----------|-----------------|-----------------|
| Tailscale auth keys | CRITICAL | 1h | Full network access |
| API tokens | HIGH | 2h | Service compromise |
| Database passwords | HIGH | 2h | Data breach |
| SSH keys | MEDIUM | 4h | Server access |
| Service passwords | MEDIUM | 4h | Service disruption |
| GPG keys | LOW | 24h | Email compromise |

### Step 1: Rotate Tailscale Auth Keys (1-2h)

**Why**: Exposed auth key allows attacker to join your Tailscale network.

```bash
# 1. Revoke old auth keys via admin console
# Visit: https://login.tailscale.com/admin/settings/keys
# Find and revoke any auth keys

# 2. Generate new auth key
# Admin console → Settings → Keys → Generate auth key
# Select options: Reusable, Ephemeral (if applicable)
# Copy new key

# 3. Update in nix-secrets
cd nix-secrets
sops sops/shared.yaml

# Update the tailscale_auth_key value
# Replace with new key from step 2

# 4. Rekey and deploy
cd ../nix-config
just rekey

# 5. Rebuild hosts that use Tailscale
ssh [host] "sudo nixos-rebuild switch --flake ~/nix-config"
```

**Verify**:
```bash
# Check Tailscale status on each host
ssh [host] "tailscale status"
# Should show connected
```

### Step 2: Rotate API Tokens (1-3h)

**Priority order**: Most critical first

1. **GitHub Personal Access Tokens**:
   ```bash
   # 1. Revoke old token
   # Visit: https://github.com/settings/tokens
   # Find old token → Delete

   # 2. Generate new token
   # Same permissions as old token
   # Copy new token

   # 3. Update in secrets
   cd nix-secrets
   sops sops/[hostname].yaml
   # Update github_token or similar field

   # 4. Redeploy
   cd ../nix-config
   just rekey
   ssh [host] "sudo nixos-rebuild switch --flake ~/nix-config"
   ```

2. **Cloud Provider Tokens** (if any):
   - AWS access keys
   - GCP service accounts
   - Azure credentials
   - DigitalOcean tokens

   For each:
   ```bash
   # 1. Revoke via provider console
   # 2. Generate new token/key
   # 3. Update in nix-secrets
   # 4. Redeploy
   ```

3. **Service API Keys** (if any):
   - Stripe API keys
   - SendGrid tokens
   - Cloudflare API tokens
   - Other third-party services

   ```bash
   # For each service:
   # 1. Login to service
   # 2. Revoke old key
   # 3. Generate new key
   # 4. Update in nix-secrets
   # 5. Redeploy
   ```

4. **Webhook Secrets**:
   ```bash
   # Update webhook secrets in services
   # GitHub webhooks
   # CI/CD webhooks
   # Other webhook consumers
   ```

### Step 3: Rotate Database Passwords (2-3h)

**For each database**:

1. **PostgreSQL**:
   ```bash
   # Connect to database
   ssh [db-host] "sudo -u postgres psql"

   # Change password
   ALTER USER dbuser WITH PASSWORD 'new-password-here';

   # Update in nix-secrets
   cd nix-secrets
   sops sops/[hostname].yaml
   # Update database password

   # Restart services that use database
   ssh [host] "sudo systemctl restart [service]"
   ```

2. **MySQL/MariaDB**:
   ```bash
   ssh [db-host] "sudo mysql"

   ALTER USER 'dbuser'@'localhost' IDENTIFIED BY 'new-password-here';
   FLUSH PRIVILEGES;
   ```

3. **Redis** (if password-protected):
   ```bash
   # Update requirepass in config
   # Update in nix-secrets
   # Restart Redis
   ```

### Step 4: Rotate SSH Keys (3-4h)

**If SSH private keys were stored in secrets**:

1. **Generate new SSH key**:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_new -C "email@example.com"
   ```

2. **Update authorized_keys on all targets**:
   ```bash
   # For each remote host
   ssh-copy-id -i ~/.ssh/id_ed25519_new.pub user@remote-host

   # OR manually:
   cat ~/.ssh/id_ed25519_new.pub | ssh user@remote-host "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
   ```

3. **Update in nix-secrets**:
   ```bash
   cd nix-secrets
   sops sops/[hostname].yaml
   # Update ssh_private_key field
   ```

4. **Remove old key from authorized_keys**:
   ```bash
   ssh user@remote-host "nano ~/.ssh/authorized_keys"
   # Delete line with old key
   ```

### Step 5: Rotate Service Passwords (3-4h)

**Admin passwords, service accounts, etc.**:

1. **List all service passwords**:
   ```bash
   cd nix-secrets
   sops -d sops/[hostname].yaml | grep -i password
   ```

2. **For each password**:
   - Generate new password (use password manager)
   - Update in service/application
   - Update in nix-secrets
   - Redeploy

**Example services**:
- Grafana admin password
- Nextcloud admin password
- Nginx basic auth passwords
- Application-specific passwords

### Step 6: Rotate GPG Keys (if applicable)

**If GPG private keys were in secrets**:

1. **Revoke old key**:
   ```bash
   gpg --gen-revoke keyid > revoke.asc
   gpg --import revoke.asc
   gpg --send-keys keyid
   ```

2. **Generate new key**:
   ```bash
   gpg --full-generate-key
   ```

3. **Update in secrets**:
   ```bash
   gpg --armor --export-secret-keys keyid > private.asc
   # Add to nix-secrets
   ```

4. **Publish new public key**:
   ```bash
   gpg --send-keys new-keyid
   ```

**CHECKLIST**:
- [ ] Tailscale auth keys rotated
- [ ] GitHub tokens rotated
- [ ] Cloud provider tokens rotated (if any)
- [ ] Service API keys rotated
- [ ] Database passwords rotated
- [ ] SSH keys rotated (if in secrets)
- [ ] Service passwords rotated
- [ ] GPG keys rotated (if applicable)
- [ ] All rotated credentials tested
- [ ] All services operational

---

## PHASE 4: MONITORING & DETECTION (T+0 to T+7d)

**Goal**: Detect if attacker accessed any services using compromised credentials.

### Immediate Monitoring (T+0 to T+4h)

**Check every 15 minutes during key/secret rotation:**

1. **Tailscale Activity Logs**:
   ```bash
   # From another device
   tailscale status
   tailscale netcheck

   # Admin console: https://login.tailscale.com/admin/machines
   # Check "Activity" tab for each device
   # Look for:
   # - Stolen device coming online
   # - New unexpected devices
   # - Unusual traffic patterns
   ```

2. **SSH Access Logs**:
   ```bash
   # On each host
   ssh [host] "sudo journalctl -u sshd --since '1 hour ago'"

   # Look for:
   # - Failed authentication attempts
   # - Successful logins from unknown IPs
   # - Unexpected connection times

   # Check auth logs
   ssh [host] "sudo journalctl | grep -i 'failed password' --since '1 hour ago'"
   ```

3. **System Logs**:
   ```bash
   # Check for unexpected rebuilds
   ssh [host] "sudo journalctl -u nixos-rebuild --since '1 hour ago'"

   # Check for secret decryption attempts
   ssh [host] "sudo journalctl | grep sops --since '1 hour ago'"
   ```

### Service-Specific Monitoring (T+0 to T+24h)

1. **GitHub Access Logs**:
   ```bash
   # Visit: https://github.com/settings/security-log
   # Look for:
   # - API token usage from unknown IPs
   # - OAuth app authorizations
   # - Repository access from stolen token
   # - SSH key additions
   ```

2. **Cloud Provider Audit Logs** (if applicable):
   - AWS CloudTrail
   - GCP Audit Logs
   - Azure Activity Log
   - Check for unexpected API calls

3. **Database Logs**:
   ```bash
   # PostgreSQL
   ssh [db-host] "sudo journalctl -u postgresql --since '1 hour ago'"

   # Check for unexpected connections
   ssh [db-host] "sudo -u postgres psql -c 'SELECT * FROM pg_stat_activity;'"
   ```

4. **Web Service Logs**:
   ```bash
   # Nginx/Apache access logs
   ssh [host] "sudo journalctl -u nginx --since '1 hour ago'"

   # Look for unusual requests
   ```

### Anomaly Detection

**Watch for**:
- Unusual API calls from unknown IPs
- New SSH connections from unexpected locations
- Unexpected system rebuilds
- Secret decryption attempts
- New device enrollments
- Data exfiltration patterns
- Service configuration changes
- New user accounts created
- Permission escalations

**How to check**:
```bash
# Create monitoring dashboard
watch -n 60 'tailscale status; ssh [host1] "last | head -10"; ssh [host2] "last | head -10"'

# Aggregate logs
for host in host1 host2 host3; do
  echo "=== $host ==="
  ssh $host "sudo journalctl --since '1 hour ago' | grep -iE 'error|fail|denied|unauthorized'"
done
```

### Continuous Monitoring (T+4h to T+7d)

**Daily checks for 7 days**:

```bash
# Daily monitoring script (run once per day for 7 days)
#!/bin/bash

echo "=== Daily Security Check - $(date) ==="

# 1. Check Tailscale for new devices
echo "Tailscale devices:"
tailscale status | grep -v "idle"

# 2. Check SSH activity on all hosts
for host in host1 host2 host3; do
  echo "=== $host SSH activity ==="
  ssh $host "last | head -10"
done

# 3. Check failed auth attempts
for host in host1 host2 host3; do
  echo "=== $host failed auths ==="
  ssh $host "sudo journalctl --since '24 hours ago' | grep -i 'failed password' | wc -l"
done

# 4. Check GitHub security log
echo "Check GitHub security log manually: https://github.com/settings/security-log"

# 5. Check for unexpected processes
for host in host1 host2 host3; do
  echo "=== $host processes ==="
  ssh $host "ps aux | grep -iE 'nix|age|sops' | grep -v grep"
done

echo "=== Check complete ==="
```

**Set calendar reminder**:
- Day 1: Run check (1 hour after incident)
- Day 2: Run check
- Day 3: Run check
- Day 4: Run check
- Day 5: Run check
- Day 6: Run check
- Day 7: Run check + post-incident review

### Alerting Setup (Optional, Future)

**Future enhancements**:
- Webhook on new Tailscale device enrollment
- Email on failed SSH attempts (> 5 in 1 hour)
- Slack/Discord notification on secret access
- Automated log analysis with anomaly detection
- SIEM integration (Wazuh, Elastic Security, etc.)

**CHECKLIST**:
- [ ] Immediate monitoring active (T+0 to T+4h)
- [ ] Service logs checked for anomalies
- [ ] GitHub access log reviewed
- [ ] Cloud provider logs checked (if applicable)
- [ ] Database access logs reviewed
- [ ] Daily monitoring scheduled for 7 days
- [ ] No evidence of unauthorized access found

---

## PHASE 5: POST-INCIDENT REVIEW (T+7d)

**Goal**: Learn from the incident and improve security posture.

### Timeline Reconstruction

**Document the complete timeline**:

1. **When was device stolen?**
   - Date/time: `____________`
   - Location: `____________`
   - How: `____________`

2. **When was theft noticed?**
   - Date/time: `____________`
   - Response delay: `____________`

3. **Response timeline**:
   - Key rotation started: `____________`
   - Key rotation completed: `____________`
   - Secret rotation completed: `____________`
   - All hosts secured: `____________`

4. **Total response time**:
   - Notice to key rotation: `____________`
   - Key rotation duration: `____________`
   - Secret rotation duration: `____________`
   - Total incident duration: `____________`

### Impact Assessment

1. **What secrets were exposed?**
   ```bash
   # List all secrets from stolen device
   cd nix-secrets
   sops -d sops/[stolen-hostname].yaml | grep -v "^sops:"
   ```

   - Secret list: `____________`
   - Sensitivity: `____________`

2. **Were secrets accessed by attacker?**
   - Evidence from logs: `____________`
   - GitHub activity: `____________`
   - Service access: `____________`
   - Verdict: `YES / NO / UNKNOWN`

3. **What services were affected?**
   - Services list: `____________`
   - Downtime: `____________`
   - Data exposure: `____________`

4. **What data was compromised?**
   - User data: `____________`
   - System data: `____________`
   - Configuration: `____________`

### Response Effectiveness

**What went well?**
- [ ] Quick detection (< 30 min)
- [ ] Fast key rotation (< 1 hour)
- [ ] Effective monitoring
- [ ] Good coordination (if team)
- [ ] Clear runbook steps
- [ ] All secrets rotated
- [ ] No service disruption
- [ ] Other: `____________`

**What went poorly?**
- [ ] Delayed detection (> 1 hour)
- [ ] Slow key rotation (> 2 hours)
- [ ] Unclear runbook steps
- [ ] Missing commands
- [ ] Incomplete secret inventory
- [ ] Service downtime occurred
- [ ] Coordination issues
- [ ] Other: `____________`

**What would you do differently?**
- `____________`
- `____________`
- `____________`

**Were runbooks accurate?**
- Accuracy rating: `1-5` (5 = perfect)
- Inaccuracies found: `____________`
- Missing steps: `____________`
- Suggested improvements: `____________`

### Improvements Needed

**Runbook updates**:
- [ ] Add missing steps: `____________`
- [ ] Fix incorrect commands: `____________`
- [ ] Add automation: `____________`
- [ ] Improve clarity: `____________`

**Infrastructure improvements**:
- [ ] Enable LUKS on remaining hosts (Plan 17-01)
- [ ] Automate key rotation (future phase)
- [ ] Reduce secret count (consolidate)
- [ ] Improve secret segmentation
- [ ] Add monitoring/alerting
- [ ] Implement backup 2FA
- [ ] Other: `____________`

**Process improvements**:
- [ ] Regular rotation drills (quarterly)
- [ ] Update contact information
- [ ] Print quick reference card
- [ ] Store offline backup copy
- [ ] Create incident report template
- [ ] Other: `____________`

### Prevention Measures

**Physical security**:
- [ ] Cable lock for laptop
- [ ] Secure storage when not in use
- [ ] Insurance coverage
- [ ] "Find My Device" enabled
- [ ] Encrypted backups

**Technical security**:
- [ ] Enable LUKS disk encryption (Plan 17-01)
- [ ] Reduce secrets per host
- [ ] Implement secret segmentation
- [ ] Increase rotation frequency
- [ ] Add monitoring alerts
- [ ] Implement hardware security module (HSM)
- [ ] Consider TPM-based decryption

**Policy/process**:
- [ ] Quarterly rotation drills
- [ ] Regular key rotation schedule
- [ ] Incident response training
- [ ] Update emergency contacts
- [ ] Review and update runbooks
- [ ] Test backup/restore procedures

### Incident Report Template

**Create formal incident report** in `incident-reports/YYYY-MM-DD-device-stolen.md`:

```markdown
# Incident Report: Device Stolen

**Date**: YYYY-MM-DD
**Device**: [hostname]
**Reporter**: [name]
**Status**: RESOLVED / ONGOING

## Executive Summary

[1-2 paragraph summary of incident, impact, and resolution]

## Timeline

- **T+0** (YYYY-MM-DD HH:MM): Device stolen at [location]
- **T+XXm**: Theft noticed by [person]
- **T+XXm**: Response initiated, runbook followed
- **T+XXm**: Device isolated from network
- **T+XXm**: Age key removed from .sops.yaml
- **T+XXm**: All secrets rekeyed
- **T+XXh**: Critical secrets rotated (Tailscale, APIs)
- **T+XXh**: All secrets rotated
- **T+XXh**: All hosts rebuilt with new secrets
- **T+XXd**: 7-day monitoring completed
- **T+XXd**: Incident closed

## Impact

**Secrets Exposed**:
- [List of secrets that were encrypted with compromised key]

**Services Affected**:
- [List of services that experienced disruption]

**Downtime**:
- Service X: [duration]
- Service Y: [duration]
- Total: [duration]

**Evidence of Unauthorized Access**:
- YES / NO / UNKNOWN
- Details: [findings from monitoring phase]

**Data Compromise**:
- User data: YES / NO
- System data: YES / NO
- Configuration: YES / NO
- Details: [explain what data was accessed]

## Response Actions

- [x] Device isolated from network (T+XXm)
- [x] Age key removed from .sops.yaml (T+XXm)
- [x] All secrets rekeyed (T+XXm)
- [x] Critical secrets rotated (T+XXh)
- [x] All secrets rotated (T+XXh)
- [x] All hosts rebuilt (T+XXh)
- [x] Monitoring enabled (T+0 to T+7d)
- [x] Post-incident review completed (T+7d)

## Lessons Learned

**What Worked**:
- [List things that went well]

**What Didn't Work**:
- [List things that went poorly]

**Improvements Needed**:
- [List specific improvements to implement]

## Prevention Measures Implemented

- [ ] LUKS enabled on remaining hosts
- [ ] Secret count reduced
- [ ] Rotation frequency increased
- [ ] Monitoring/alerting added
- [ ] Physical security improved
- [ ] Insurance claim filed
- [ ] Police report filed

## Follow-Up Actions

- [ ] Update runbooks based on findings
- [ ] Implement automation improvements
- [ ] Schedule quarterly rotation drills
- [ ] Review and update emergency contacts
- [ ] Test backup/restore procedures

## Sign-Off

**Incident Commander**: [name]
**Date**: YYYY-MM-DD
**Status**: CLOSED

**Approver**: [name]
**Date**: YYYY-MM-DD
```

**CHECKLIST**:
- [ ] Timeline reconstructed completely
- [ ] Impact assessment completed
- [ ] Response effectiveness analyzed
- [ ] Improvements identified
- [ ] Prevention measures planned
- [ ] Formal incident report created
- [ ] Follow-up actions scheduled

---

## Quick Reference

**See**: `docs/incident-response/QUICK-REFERENCE.md` for one-page emergency guide.

**Full rotation details**: `docs/sops-rotation.md`

**Key rotation script**: `scripts/sops-rotate.sh`

**Justfile commands**:
- `just rekey` - Rekey all secrets
- `just sops-rotate [host]` - Interactive key rotation
- `just sops-check-key-age` - Check key ages

---

## Testing This Runbook

**IMPORTANT**: Test this runbook BEFORE you need it.

**Quarterly drill procedure**:
1. Pick a test VM (griefling, sorrow, torment)
2. Simulate device theft
3. Follow this runbook completely
4. Time each phase
5. Document issues/improvements
6. Update runbook based on findings

**Drill checklist**:
- [ ] Test key removal
- [ ] Test rekeying
- [ ] Test secret rotation
- [ ] Test monitoring commands
- [ ] Verify all commands work
- [ ] Time each phase
- [ ] Update runbook with findings

---

## Appendix: Response Time Targets

| Milestone | Target | Acceptable | Poor |
|-----------|--------|------------|------|
| Notice theft | < 30 min | < 2 hours | > 4 hours |
| Begin response | < 15 min | < 30 min | > 1 hour |
| Key rotation | < 1 hour | < 2 hours | > 4 hours |
| Critical secrets | < 2 hours | < 4 hours | > 8 hours |
| All secrets | < 4 hours | < 8 hours | > 24 hours |
| Monitoring duration | 7 days | 3 days | 1 day |

---

## Appendix: Prevention vs. Response

**This runbook is damage control, not prevention.**

**Better approaches** (from Phase 17-01):
- **LUKS disk encryption**: Prevents key extraction from stolen device
- **TPM-based decryption**: Keys can't be extracted without hardware
- **Secret segmentation**: Limit blast radius of compromised key
- **Regular rotation**: Reduce impact window of old secrets
- **Monitoring**: Detect theft faster

**Recommendation**: Implement Plan 17-01 (LUKS encryption) BEFORE deploying to production.

---

## Document Version

**Version**: 1.0
**Created**: 2025-12-16
**Last Updated**: 2025-12-16
**Phase**: 17-02
**Status**: FUTURE WORK - Review before deployment
