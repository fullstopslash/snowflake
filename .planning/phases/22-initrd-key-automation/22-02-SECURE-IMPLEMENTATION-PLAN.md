---
phase: 22-initrd-key-automation
type: execute
security-critical: true
---

<objective>
Implement SOPS-encrypted initrd SSH key and Clevis token management with defense-in-depth security.

Purpose: Replace the insecure plain-text key storage with a proper SOPS-encrypted architecture that maintains zero-touch deployment while ensuring all secrets are encrypted at rest in nix-secrets.

Output: Production-ready, security-hardened workflow where all private keys and tokens are SOPS-encrypted in nix-secrets, deployed securely via nixos-anywhere, and accessible from /persist on target hosts.

Security Requirements:
- ✅ NO private keys in plain text EVER
- ✅ All secrets SOPS-encrypted in nix-secrets
- ✅ Per-host isolation (unique keys per host)
- ✅ Per-disk tokens (multiple encrypted disks supported)
- ✅ Defense in depth (even TPM-bound tokens encrypted)
- ✅ Build-time safety (nix store never contains secrets)
</objective>

<execution_context>
Reference:
- .planning/phases/22-initrd-key-automation/SECURITY-ARCHITECTURE.md
- Research: Clevis TPM2 tokens are TPM-bound but should still be SOPS-encrypted for defense in depth
- Previous incident: Plain text secrets were committed (now purged)

Security Model:
- Initrd SSH private keys: SOPS-encrypted in sops/<hostname>.yaml
- Clevis JWE tokens: SOPS-encrypted in sops/<hostname>.yaml (defense in depth)
- Public keys: Plain text in ssh/initrd-public/ (not secrets)
- Deployment: Secrets decrypted during install, placed in /persist, bcachefs-unlock.nix copies from /persist
</execution_context>

<context>
@.planning/phases/22-initrd-key-automation/SECURITY-ARCHITECTURE.md
@justfile (vm-fresh, install recipes)
@modules/disks/bcachefs-unlock.nix
@scripts/helpers.sh (SOPS helpers)

Research findings:
- Clevis TPM2 tokens can ONLY be decrypted by the specific TPM hardware
- Attacker with token file alone: Cannot decrypt (needs physical TPM access)
- Attacker with token + physical machine access: Can decrypt
- Conclusion: SOPS-encrypt tokens for defense in depth

Implementation approach:
1. Update bcachefs-unlock.nix to use /persist instead of nix-secrets
2. Update vm-fresh/install to SOPS-encrypt keys before committing
3. Create helper script for Clevis token management
4. Test complete workflow on anguish VM
</context>

<tasks>

<task type="auto">
  <name>Task 1: Update bcachefs-unlock.nix to use /persist paths</name>
  <files>modules/disks/bcachefs-unlock.nix</files>
  <action>
Currently bcachefs-unlock.nix expects keys in nix-secrets (WRONG):
```nix
initrdSshKeySource = "${builtins.toString inputs.nix-secrets}/ssh/initrd/${hostCfg.hostName}_initrd_ed25519";
```

Update to use /persist where SOPS-deployed secrets live (CORRECT):

Around lines 54-58, change:
```nix
# Initrd SSH host key paths
# Deployed to /persist via SOPS or nixos-anywhere --extra-files
# bcachefs encryption protects /persist at rest
initrdSshKeySource = "${hostCfg.persistFolder}/etc/ssh/initrd_ssh_host_ed25519_key";
initrdSshKeyPersist = initrdSshKeySource; # Same location
```

Around lines 49-52, change Clevis token paths:
```nix
# Clevis JWE token paths
# Stored in /persist, copied to initrd at build time
# Token is TPM-bound + SOPS-encrypted in nix-secrets (defense in depth)
clevisTokenSource = "${hostCfg.persistFolder}/etc/clevis/bcachefs-root.jwe";
clevisTokenPersist = clevisTokenSource; # Same location
```

Remove the old nix-secrets reference completely.

Update the pathExists checks:
- Line 100: Change to check initrdSshKeySource (now points to /persist)
- Line 141-148: Change to check clevisTokenSource (now points to /persist)

Rationale:
- SOPS-encrypted secrets cannot be in nix store (would expose them)
- Secrets are deployed to /persist during installation
- /persist is encrypted by bcachefs, so secrets protected at rest
- Build-time: nix just copies from /persist to initrd
- No SOPS decryption needed during build (already on disk)
  </action>
  <verify>
- nix flake check passes
- No references to ${inputs.nix-secrets}/ssh/initrd/ remain
- No references to nix-secrets clevis paths remain
- All paths point to ${hostCfg.persistFolder}/etc/
- Build test: nix build .#nixosConfigurations.anguish.config.system.build.toplevel
  </verify>
  <done>
- bcachefs-unlock.nix updated to use /persist paths
- No nix-secrets references for secrets
- Public keys can still reference nix-secrets (not secrets)
- Module will copy from /persist to initrd at build time
  </done>
</task>

<task type="auto">
  <name>Task 2: Create SOPS helper functions for key management</name>
  <files>scripts/sops-key-helpers.sh</files>
  <action>
Create new helper script for SOPS key operations:

```bash
#!/usr/bin/env bash
# SOPS helper functions for secure key management

# Store initrd SSH private key in SOPS
# Usage: sops_store_initrd_key <hostname> <private_key_file>
sops_store_initrd_key() {
    local hostname="$1"
    local key_file="$2"
    local sops_file="../nix-secrets/sops/${hostname}.yaml"

    if [ ! -f "$key_file" ]; then
        echo "ERROR: Key file not found: $key_file" >&2
        return 1
    fi

    # Read the private key
    local key_content
    key_content=$(cat "$key_file")

    # Store in SOPS using sops --set
    # Creates the path if it doesn't exist
    sops --set "[\"initrd\"][\"ssh_host_ed25519_key\"] \"$key_content\"" "$sops_file"

    echo "✅ Stored initrd SSH key for $hostname in SOPS"
}

# Retrieve initrd SSH private key from SOPS
# Usage: sops_get_initrd_key <hostname>
sops_get_initrd_key() {
    local hostname="$1"
    local sops_file="../nix-secrets/sops/${hostname}.yaml"

    if [ ! -f "$sops_file" ]; then
        echo "ERROR: SOPS file not found: $sops_file" >&2
        return 1
    fi

    # Extract the key using sops --extract
    sops --extract '["initrd"]["ssh_host_ed25519_key"]' "$sops_file" 2>/dev/null
}

# Store Clevis token in SOPS
# Usage: sops_store_clevis_token <hostname> <disk_name> <token_file>
# Example: sops_store_clevis_token anguish bcachefs-root /persist/etc/clevis/bcachefs-root.jwe
sops_store_clevis_token() {
    local hostname="$1"
    local disk_name="$2"  # e.g., "bcachefs-root", "bcachefs-data"
    local token_file="$3"
    local sops_file="../nix-secrets/sops/${hostname}.yaml"

    if [ ! -f "$token_file" ]; then
        echo "ERROR: Token file not found: $token_file" >&2
        return 1
    fi

    # Read the JWE token (it's JSON)
    local token_content
    token_content=$(cat "$token_file")

    # Store in SOPS under clevis/<disk_name>/token
    sops --set "[\"clevis\"][\"$disk_name\"][\"token\"] '$token_content'" "$sops_file"

    echo "✅ Stored Clevis token for $hostname/$disk_name in SOPS"
}

# Retrieve Clevis token from SOPS
# Usage: sops_get_clevis_token <hostname> <disk_name>
sops_get_clevis_token() {
    local hostname="$1"
    local disk_name="$2"
    local sops_file="../nix-secrets/sops/${hostname}.yaml"

    if [ ! -f "$sops_file" ]; then
        echo "ERROR: SOPS file not found: $sops_file" >&2
        return 1
    fi

    # Extract the token
    sops --extract "[\"clevis\"][\"$disk_name\"][\"token\"]" "$sops_file" 2>/dev/null
}

# Export functions
export -f sops_store_initrd_key
export -f sops_get_initrd_key
export -f sops_store_clevis_token
export -f sops_get_clevis_token
```

Make executable:
```bash
chmod +x scripts/sops-key-helpers.sh
```

Add to scripts/helpers.sh to auto-source:
```bash
# Load SOPS key helpers
source "$(dirname "${BASH_SOURCE[0]}")/sops-key-helpers.sh"
```
  </action>
  <verify>
- File created at scripts/sops-key-helpers.sh
- File is executable (chmod +x)
- Functions are exported
- Sourced in scripts/helpers.sh
- Test: source scripts/sops-key-helpers.sh && type sops_store_initrd_key
  </verify>
  <done>
- SOPS helper functions created
- Auto-sourced in scripts/helpers.sh
- Ready for use in vm-fresh and install recipes
  </done>
</task>

<task type="auto">
  <name>Task 3: Update vm-fresh recipe for SOPS-encrypted keys</name>
  <files>justfile</files>
  <action>
Update the vm-fresh recipe to SOPS-encrypt initrd keys instead of storing in plain text.

**Current flow (WRONG - lines 263-268):**
```bash
# Generate initrd SSH host key for encrypted hosts (remote unlock)
mkdir -p "$EXTRA_FILES/persist/etc/ssh"
ssh-keygen -t ed25519 -f "$EXTRA_FILES/persist/etc/ssh/initrd_ssh_host_ed25519_key" -N "" -q
chmod 600 "$EXTRA_FILES/persist/etc/ssh/initrd_ssh_host_ed25519_key"
chmod 644 "$EXTRA_FILES/persist/etc/ssh/initrd_ssh_host_ed25519_key.pub"
echo "   Initrd SSH host key generated for remote unlock"
```

**New secure flow:**

Replace the initrd key generation section (around lines 263-268) with:

```bash
# Generate initrd SSH host key for encrypted hosts (remote unlock)
echo "🔑 Generating initrd SSH host key..."
INITRD_KEY_DIR=$(mktemp -d)
ssh-keygen -t ed25519 -f "$INITRD_KEY_DIR/initrd_key" -N "" -C "root@{{HOST}}-initrd" -q
chmod 600 "$INITRD_KEY_DIR/initrd_key"
chmod 644 "$INITRD_KEY_DIR/initrd_key.pub"

# Store public key in nix-secrets for reference (not a secret)
mkdir -p ../nix-secrets/ssh/initrd-public
cp "$INITRD_KEY_DIR/initrd_key.pub" "../nix-secrets/ssh/initrd-public/{{HOST}}_initrd_ed25519.pub"
INITRD_FINGERPRINT=$(ssh-keygen -lf "$INITRD_KEY_DIR/initrd_key.pub")
echo "   Initrd SSH fingerprint: $INITRD_FINGERPRINT"

# SOPS-encrypt private key in nix-secrets (SECURE)
echo "   SOPS-encrypting initrd private key..."
source {{HELPERS_PATH}}
sops_store_initrd_key {{HOST}} "$INITRD_KEY_DIR/initrd_key"

# Place decrypted key in extra-files for deployment
mkdir -p "$EXTRA_FILES/persist/etc/ssh"
cp "$INITRD_KEY_DIR/initrd_key" "$EXTRA_FILES/persist/etc/ssh/initrd_ssh_host_ed25519_key"
chmod 600 "$EXTRA_FILES/persist/etc/ssh/initrd_ssh_host_ed25519_key"

# Clean up temp key
rm -rf "$INITRD_KEY_DIR"
echo "   ✅ Initrd SSH key generated and SOPS-encrypted"
```

**Update the commit message (around line 323):**

Change from:
```bash
(vcs_commit "chore: register {{HOST}} keys (age + initrd SSH) and rekey secrets" || true)
```

To:
```bash
(vcs_commit "chore: register {{HOST}} keys (age + SOPS-encrypted initrd SSH) and rekey secrets" || true)
```

This ensures:
1. Private key SOPS-encrypted before committing to nix-secrets
2. Public key stored for TOFU verification
3. Decrypted key deployed via --extra-files to /persist
4. Temp key cleaned up (no traces)
  </action>
  <verify>
- vm-fresh recipe updated with SOPS encryption
- Public key stored in ssh/initrd-public/
- Private key SOPS-encrypted in sops/<host>.yaml
- Decrypted key deployed to /persist via --extra-files
- Temp directory cleaned up
- Test: just vm-fresh griefling (on a test host)
  </verify>
  <done>
- vm-fresh recipe updated for secure key management
- SOPS encryption integrated
- Public keys preserved for TOFU
- Private keys never in plain text
  </done>
</task>

<task type="auto">
  <name>Task 4: Update install recipe for SOPS-encrypted keys</name>
  <files>justfile</files>
  <action>
Apply the same SOPS-encrypted key flow to the install recipe (for physical machines).

Find the initrd key generation section in the install recipe (around lines 119-124) and replace with the same secure flow from Task 3:

```bash
# Generate initrd SSH host key for encrypted hosts (remote unlock)
echo "🔑 Generating initrd SSH host key..."
INITRD_KEY_DIR=$(mktemp -d)
ssh-keygen -t ed25519 -f "$INITRD_KEY_DIR/initrd_key" -N "" -C "root@{{HOST}}-initrd" -q
chmod 600 "$INITRD_KEY_DIR/initrd_key"
chmod 644 "$INITRD_KEY_DIR/initrd_key.pub"

# Store public key in nix-secrets for reference (not a secret)
mkdir -p ../nix-secrets/ssh/initrd-public
cp "$INITRD_KEY_DIR/initrd_key.pub" "../nix-secrets/ssh/initrd-public/{{HOST}}_initrd_ed25519.pub"
INITRD_FINGERPRINT=$(ssh-keygen -lf "$INITRD_KEY_DIR/initrd_key.pub")
echo "   Initrd SSH fingerprint: $INITRD_FINGERPRINT"

# SOPS-encrypt private key in nix-secrets (SECURE)
echo "   SOPS-encrypting initrd private key..."
source {{HELPERS_PATH}}
sops_store_initrd_key {{HOST}} "$INITRD_KEY_DIR/initrd_key"

# Place decrypted key in extra-files for deployment
mkdir -p "$EXTRA_FILES/persist/etc/ssh"
cp "$INITRD_KEY_DIR/initrd_key" "$EXTRA_FILES/persist/etc/ssh/initrd_ssh_host_ed25519_key"
chmod 600 "$EXTRA_FILES/persist/etc/ssh/initrd_ssh_host_ed25519_key"

# Clean up temp key
rm -rf "$INITRD_KEY_DIR"
echo "   ✅ Initrd SSH key generated and SOPS-encrypted"
```

Update the commit message similarly to use "SOPS-encrypted initrd SSH".
  </action>
  <verify>
- install recipe updated with SOPS encryption
- Same secure flow as vm-fresh
- Works for physical machine deployments
- Test: Would need physical machine or VM booted from ISO
  </verify>
  <done>
- install recipe updated for secure key management
- Consistent with vm-fresh approach
- Physical machines now use SOPS encryption
  </done>
</task>

<task type="auto">
  <name>Task 5: Create Clevis token management helper script</name>
  <files>scripts/clevis-token-manager.sh</files>
  <action>
Create a helper script for managing Clevis tokens with SOPS encryption:

```bash
#!/usr/bin/env bash
# Clevis Token Manager - SOPS-encrypted token management
set -euo pipefail

# Source SOPS helpers
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/sops-key-helpers.sh"
source "$SCRIPT_DIR/helpers.sh"

usage() {
    cat <<EOF
Clevis Token Manager - Manage SOPS-encrypted Clevis tokens

Usage:
    $0 generate <hostname> <disk_name> [<pcr_ids>]
    $0 backup <hostname> <disk_name>
    $0 restore <hostname> <disk_name>
    $0 list <hostname>

Commands:
    generate    Generate new Clevis token and SOPS-encrypt it
    backup      Backup token from /persist to SOPS (if not already there)
    restore     Restore token from SOPS to /persist
    list        List all tokens for a host

Arguments:
    hostname    Hostname (e.g., anguish)
    disk_name   Disk identifier (e.g., bcachefs-root, bcachefs-data)
    pcr_ids     TPM PCR IDs to bind (default: 0,7)

Examples:
    # Generate token for anguish root filesystem
    $0 generate anguish bcachefs-root

    # Backup existing token to SOPS
    $0 backup anguish bcachefs-root

    # Restore token from SOPS to /persist
    $0 restore anguish bcachefs-root

Security:
    - Tokens are SOPS-encrypted in sops/<hostname>.yaml
    - TPM-bound tokens provide hardware-based protection
    - SOPS encryption provides defense in depth
    - Never store tokens in plain text in git
EOF
    exit 1
}

generate_token() {
    local hostname="$1"
    local disk_name="$2"
    local pcr_ids="${3:-0,7}"

    echo "🔐 Generating Clevis TPM token for $hostname/$disk_name..."

    # Get disk password from SOPS
    local disk_password
    disk_password=$(sops_get_disk_password "$hostname")
    if [ -z "$disk_password" ]; then
        echo "ERROR: Failed to retrieve disk password from SOPS" >&2
        exit 1
    fi

    # Generate token bound to TPM with specified PCRs
    echo "   Binding to TPM PCRs: $pcr_ids"
    local token
    token=$(echo "$disk_password" | clevis encrypt tpm2 "{\"pcr_ids\":\"$pcr_ids\"}")

    # Save to /persist
    local token_path="/persist/etc/clevis/${disk_name}.jwe"
    mkdir -p "$(dirname "$token_path")"
    echo "$token" > "$token_path"
    chmod 600 "$token_path"
    echo "   Token saved to: $token_path"

    # SOPS-encrypt and store in nix-secrets
    echo "   SOPS-encrypting token..."
    sops_store_clevis_token "$hostname" "$disk_name" "$token_path"

    # Commit to nix-secrets
    cd ../nix-secrets
    source "$(dirname "${BASH_SOURCE[0]}")/vcs-helpers.sh"
    vcs_add "sops/${hostname}.yaml"
    vcs_commit "feat: add Clevis token for $hostname/$disk_name (SOPS-encrypted)" || true

    echo "✅ Token generated and SOPS-encrypted for $hostname/$disk_name"
}

backup_token() {
    local hostname="$1"
    local disk_name="$2"
    local token_path="/persist/etc/clevis/${disk_name}.jwe"

    if [ ! -f "$token_path" ]; then
        echo "ERROR: Token not found at $token_path" >&2
        exit 1
    fi

    echo "📦 Backing up Clevis token for $hostname/$disk_name..."
    sops_store_clevis_token "$hostname" "$disk_name" "$token_path"

    # Commit to nix-secrets
    cd ../nix-secrets
    source "$(dirname "${BASH_SOURCE[0]}")/vcs-helpers.sh"
    vcs_add "sops/${hostname}.yaml"
    vcs_commit "chore: backup Clevis token for $hostname/$disk_name" || true

    echo "✅ Token backed up to SOPS"
}

restore_token() {
    local hostname="$1"
    local disk_name="$2"
    local token_path="/persist/etc/clevis/${disk_name}.jwe"

    echo "📥 Restoring Clevis token for $hostname/$disk_name..."

    local token
    token=$(sops_get_clevis_token "$hostname" "$disk_name")
    if [ -z "$token" ]; then
        echo "ERROR: Token not found in SOPS for $hostname/$disk_name" >&2
        exit 1
    fi

    mkdir -p "$(dirname "$token_path")"
    echo "$token" > "$token_path"
    chmod 600 "$token_path"

    echo "✅ Token restored to $token_path"
}

list_tokens() {
    local hostname="$1"
    local sops_file="../nix-secrets/sops/${hostname}.yaml"

    if [ ! -f "$sops_file" ]; then
        echo "ERROR: No SOPS file found for $hostname" >&2
        exit 1
    fi

    echo "Clevis tokens for $hostname:"
    echo ""

    # Extract clevis section if it exists
    if sops --extract '["clevis"]' "$sops_file" 2>/dev/null | jq -r 'keys[]' 2>/dev/null; then
        : # Success, keys printed
    else
        echo "  No tokens found"
    fi
}

# Main
case "${1:-}" in
    generate)
        [ $# -lt 3 ] && usage
        generate_token "$2" "$3" "${4:-0,7}"
        ;;
    backup)
        [ $# -lt 3 ] && usage
        backup_token "$2" "$3"
        ;;
    restore)
        [ $# -lt 3 ] && usage
        restore_token "$2" "$3"
        ;;
    list)
        [ $# -lt 2 ] && usage
        list_tokens "$2"
        ;;
    *)
        usage
        ;;
esac
```

Make executable:
```bash
chmod +x scripts/clevis-token-manager.sh
```
  </action>
  <verify>
- Script created at scripts/clevis-token-manager.sh
- Executable permissions set
- All functions work with SOPS helpers
- Test help: scripts/clevis-token-manager.sh
- Test list: scripts/clevis-token-manager.sh list anguish
  </verify>
  <done>
- Clevis token manager script created
- SOPS integration complete
- Commands: generate, backup, restore, list
- Ready for production use
  </done>
</task>

<task type="auto">
  <name>Task 6: Update justfile bcachefs-setup-tpm to use SOPS</name>
  <files>justfile</files>
  <action>
The bcachefs-setup-tpm recipe currently generates tokens but doesn't SOPS-encrypt them.

Find the bcachefs-setup-tpm recipe and update it to use the new Clevis token manager:

Replace the recipe (around lines 709-764) with:

```bash
# Generate TPM token for bcachefs encryption using secure SOPS workflow
# Usage:
#   just bcachefs-setup-tpm HOST        # Post-boot (on running system)
#   just bcachefs-setup-tpm HOST /mnt   # During install (from installer)
bcachefs-setup-tpm HOST MOUNT_ROOT="" DISK_NAME="bcachefs-root":
    #!/usr/bin/env bash
    set -euo pipefail

    # Determine if running during install or on live system
    if [ -n "{{MOUNT_ROOT}}" ]; then
        echo "🔐 Generating TPM token during installation (mount root: {{MOUNT_ROOT}})"
        IS_INSTALL=true
        # During install, we'll use the clevis-token-manager after chroot
        echo "ERROR: Install-time token generation not yet supported with SOPS"
        echo "       Generate token after first boot using: just bcachefs-setup-tpm {{HOST}}"
        exit 1
    else
        echo "🔐 Generating TPM token on running system {{HOST}}"
        IS_INSTALL=false
    fi

    # Get PCR IDs from host configuration
    PCR_IDS=$(nix eval --raw .#nixosConfigurations.{{HOST}}.config.host.encryption.tpm.pcrIds 2>/dev/null || echo "0,7")
    echo "   PCR IDs: $PCR_IDS"

    # Use the Clevis token manager
    ./scripts/clevis-token-manager.sh generate {{HOST}} {{DISK_NAME}} "$PCR_IDS"

    echo ""
    echo "✅ TPM token generated and SOPS-encrypted"
    echo "   Rebuild system to include token in initrd:"
    echo "   sudo nixos-rebuild boot"
```

This simplifies the recipe and ensures SOPS encryption is always used.
  </action>
  <verify>
- bcachefs-setup-tpm recipe updated
- Uses clevis-token-manager.sh
- SOPS encryption automatic
- Clear error for install-time generation (TODO)
- Test: just bcachefs-setup-tpm anguish
  </verify>
  <done>
- bcachefs-setup-tpm updated to use SOPS
- Simplified recipe delegates to token manager
- SOPS encryption enforced
- Install-time generation documented as TODO
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>
Complete SOPS-encrypted architecture for initrd SSH keys and Clevis tokens:

1. **bcachefs-unlock.nix:** Updated to use /persist paths instead of nix-secrets
2. **SOPS helpers:** Created sops-key-helpers.sh for secure key operations
3. **vm-fresh recipe:** Updated to SOPS-encrypt initrd keys before committing
4. **install recipe:** Updated with same SOPS-encrypted flow
5. **Clevis token manager:** New script for managing SOPS-encrypted tokens
6. **bcachefs-setup-tpm:** Updated to use token manager with SOPS

All changes follow the security architecture:
- ✅ Private keys SOPS-encrypted
- ✅ Public keys in plain text for TOFU
- ✅ Defense in depth for Clevis tokens
- ✅ Per-host, per-disk isolation
- ✅ No secrets in nix store
</what-built>
  <how-to-verify>
**Code Review:**
- [ ] Review all modified files for security issues
- [ ] Verify no plain text secret storage remains
- [ ] Check SOPS encryption is used everywhere
- [ ] Confirm /persist paths used (not nix-secrets)
- [ ] Validate temp file cleanup

**Architecture Review:**
- [ ] Initrd SSH keys: SOPS-encrypted in sops/<host>.yaml ✓
- [ ] Clevis tokens: SOPS-encrypted in sops/<host>.yaml ✓
- [ ] Public keys: Plain text in ssh/initrd-public/ ✓
- [ ] Deployment: Decrypted to /persist, bcachefs protects at rest ✓
- [ ] Build-time: Copy from /persist (no SOPS needed) ✓

**Security Concerns:**
- [ ] Any remaining plain text secrets?
- [ ] Any hardcoded passwords?
- [ ] Temp files properly cleaned?
- [ ] SOPS errors handled gracefully?

If all checks pass, approve for implementation.
  </how-to-verify>
  <resume-signal>Type "approved" to proceed with implementation, or describe concerns</resume-signal>
</task>

<task type="auto">
  <name>Task 7: Test on anguish VM - Generate new SOPS-encrypted keys</name>
  <files>None (testing task)</files>
  <action>
After approval, test the complete secure workflow on anguish:

1. **Generate SOPS-encrypted initrd key manually:**
   ```bash
   # Generate new key
   TEMP_KEY=$(mktemp -d)
   ssh-keygen -t ed25519 -f "$TEMP_KEY/key" -N "" -C "root@anguish-initrd"

   # Store public key
   cp "$TEMP_KEY/key.pub" ../nix-secrets/ssh/initrd-public/anguish_initrd_ed25519.pub

   # SOPS-encrypt private key
   source scripts/sops-key-helpers.sh
   sops_store_initrd_key anguish "$TEMP_KEY/key"

   # Verify
   sops_get_initrd_key anguish | head -1  # Should show key header

   # Deploy to anguish /persist
   DECRYPTED_KEY=$(sops_get_initrd_key anguish)
   ssh -p 22225 rain@127.0.0.1 "sudo mkdir -p /persist/etc/ssh && sudo tee /persist/etc/ssh/initrd_ssh_host_ed25519_key > /dev/null && sudo chmod 600 /persist/etc/ssh/initrd_ssh_host_ed25519_key" <<< "$DECRYPTED_KEY"

   # Clean up
   rm -rf "$TEMP_KEY"
   ```

2. **Commit to nix-secrets:**
   ```bash
   cd ../nix-secrets
   git add sops/anguish.yaml ssh/initrd-public/anguish_initrd_ed25519.pub
   git commit -m "feat: add SOPS-encrypted initrd SSH key for anguish"
   git push
   ```

3. **Update nix-config flake:**
   ```bash
   cd ~/nix-config
   nix flake update nix-secrets
   ```

4. **Rebuild anguish:**
   ```bash
   ssh -p 22225 rain@127.0.0.1 'cd ~/nix-config && nh os boot'
   ```

5. **Reboot and test remote unlock:**
   ```bash
   ssh -p 22225 rain@127.0.0.1 'sudo reboot'
   sleep 10
   # Try initrd SSH
   ssh -p 2222 root@127.0.0.1
   ```

Expected results:
- Initrd SSH connects with persistent fingerprint
- Fingerprint matches public key in nix-secrets
- System unlocks and boots normally
  </action>
  <verify>
- SOPS-encrypted key in sops/anguish.yaml
- Public key in ssh/initrd-public/
- Key deployed to /persist on anguish
- Rebuild successful
- Initrd SSH works with persistent fingerprint
- Fingerprint matches: ssh-keygen -lf ../nix-secrets/ssh/initrd-public/anguish_initrd_ed25519.pub
  </verify>
  <done>
- SOPS-encrypted initrd SSH key working on anguish
- Remote unlock via SSH verified
- Persistent fingerprint confirmed
- Complete workflow tested end-to-end
  </done>
</task>

<task type="auto">
  <name>Task 8: Generate and SOPS-encrypt Clevis token for anguish</name>
  <files>None (testing task)</files>
  <action>
Test the Clevis token SOPS encryption workflow:

1. **Generate token on anguish:**
   ```bash
   # SSH to anguish
   ssh -p 22225 rain@127.0.0.1

   # Run token manager from nix-config
   cd ~/nix-config
   sudo scripts/clevis-token-manager.sh generate anguish bcachefs-root 0,7
   ```

2. **Verify token in SOPS:**
   ```bash
   # From local machine
   sops --extract '["clevis"]["bcachefs-root"]' ../nix-secrets/sops/anguish.yaml
   # Should show encrypted token
   ```

3. **Rebuild with token in initrd:**
   ```bash
   ssh -p 22225 rain@127.0.0.1 'cd ~/nix-config && nh os boot'
   ```

4. **Test automatic TPM unlock:**
   ```bash
   ssh -p 22225 rain@127.0.0.1 'sudo reboot'
   # Wait ~30 seconds
   # Should boot automatically without password prompt
   ssh -p 22225 rain@127.0.0.1 'echo "Automatic unlock successful!"'
   ```

Expected results:
- Token generated and SOPS-encrypted
- Token stored in /persist/etc/clevis/bcachefs-root.jwe
- Token also in SOPS at sops/anguish.yaml
- Automatic TPM unlock works on reboot
- No password prompt needed
  </action>
  <verify>
- Token in /persist/etc/clevis/bcachefs-root.jwe
- Token SOPS-encrypted in sops/anguish.yaml
- Automatic TPM unlock working
- journalctl shows successful Clevis decrypt
- No password prompts during boot
  </verify>
  <done>
- Clevis token SOPS-encrypted and working
- Automatic TPM unlock verified
- Defense in depth achieved (TPM + SOPS)
- Complete secure workflow operational
  </done>
</task>

<task type="auto">
  <name>Task 9: Update documentation with secure workflow</name>
  <files>docs/remote-unlock.md, .planning/phases/22-initrd-key-automation/22-02-SUMMARY.md</files>
  <action>
Create comprehensive documentation for the secure SOPS-encrypted workflow.

Update docs/remote-unlock.md to include:
- SOPS encryption for all secrets
- New clevis-token-manager.sh usage
- Updated vm-fresh workflow
- Security model explanation
- TOFU verification with public keys

Create 22-02-SUMMARY.md documenting:
- Security incident and resolution
- SOPS-encrypted architecture
- All changes made
- Testing results
- Production readiness statement
  </action>
  <verify>
- Documentation updated with secure workflow
- SOPS encryption clearly documented
- Security model explained
- Examples use SOPS helpers
- Summary created with all changes
  </verify>
  <done>
- Complete documentation created
- Secure workflow documented
- Security model clear
- Ready for production use
  </done>
</task>

<task type="auto">
  <name>Task 10: Commit all changes to nix-config</name>
  <files>ALL</files>
  <action>
Commit all security updates to nix-config:

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat(security): implement SOPS-encrypted initrd SSH and Clevis token management

BREAKING CHANGE: Initrd SSH keys now SOPS-encrypted instead of plain text

This implements a security-hardened workflow for managing initrd SSH keys
and Clevis TPM tokens with defense-in-depth encryption.

Security incident resolution:
- Previous implementation stored private keys in plain text in git
- Keys have been purged from git history (force-pushed nix-secrets)
- All secrets now SOPS-encrypted in per-host YAML files

Architecture changes:
- Initrd SSH private keys: SOPS-encrypted in sops/<hostname>.yaml
- Clevis JWE tokens: SOPS-encrypted (defense in depth, even though TPM-bound)
- Public keys: Plain text in nix-secrets/ssh/initrd-public/ for TOFU
- Deployment: Secrets decrypted to /persist, bcachefs protects at rest
- Build-time: bcachefs-unlock.nix copies from /persist (no SOPS needed)

Files modified:
- modules/disks/bcachefs-unlock.nix: Use /persist paths instead of nix-secrets
- scripts/sops-key-helpers.sh: New SOPS helper functions
- scripts/clevis-token-manager.sh: New token management tool
- justfile: Updated vm-fresh, install, bcachefs-setup-tpm for SOPS

Security benefits:
✅ Private keys never in plain text
✅ SOPS-encrypted at rest in nix-secrets
✅ Per-host, per-disk isolation
✅ Defense in depth (TPM + SOPS for tokens)
✅ Programmatic management
✅ Build-time safety (nix store never contains secrets)

Testing:
- Verified on anguish VM
- Remote unlock via initrd SSH working
- TPM automatic unlock working
- SOPS encryption/decryption working
- Persistent fingerprints confirmed

Closes Phase 22 (Initrd Key Automation)
EOF
)"
```

Create git tag for security milestone:
```bash
git tag -a security-hardening-2025-12-19 -m "Security hardening: SOPS-encrypted initrd keys and Clevis tokens"
```
  </action>
  <verify>
- All files staged and committed
- Commit message documents security changes
- Git tag created for milestone
- Ready to push
  </verify>
  <done>
- All changes committed
- Security milestone tagged
- Ready for production deployment
  </done>
</task>

</tasks>

<verification>
Before declaring complete:
- [ ] bcachefs-unlock.nix uses /persist paths only
- [ ] SOPS helpers created and working
- [ ] vm-fresh SOPS-encrypts initrd keys
- [ ] install recipe SOPS-encrypts initrd keys
- [ ] clevis-token-manager.sh created and tested
- [ ] bcachefs-setup-tpm uses SOPS
- [ ] Tested on anguish VM (initrd SSH + TPM)
- [ ] No plain text secrets in nix-config or nix-secrets
- [ ] Git history clean (secrets purged)
- [ ] Documentation complete
- [ ] All changes committed
</verification>

<success_criteria>
- All tasks completed successfully
- All verification checks pass
- No plain text secrets anywhere
- SOPS encryption working end-to-end
- Remote unlock working on anguish
- TPM automatic unlock working on anguish
- Public keys available for TOFU verification
- Defense in depth achieved
- Production-ready for all encrypted hosts
- Security incident fully resolved
</success_criteria>

<output>
After completion, this plan delivers:
- `.planning/phases/22-initrd-key-automation/22-02-SUMMARY.md` - Complete summary
- SOPS-encrypted architecture fully operational
- All secrets properly encrypted in nix-secrets
- Secure deployment workflow for all hosts
- Complete documentation and examples

This resolves the critical security incident and establishes proper OPSEC for all future encrypted host deployments.
</output>
