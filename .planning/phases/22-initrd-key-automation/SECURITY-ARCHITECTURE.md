# Secure Initrd SSH Key & Clevis Token Architecture

## Security Requirements

1. **Private keys NEVER in plain text** - All private keys must be SOPS-encrypted in nix-secrets
2. **Per-host secrets** - Each host has unique initrd SSH keys and Clevis tokens
3. **Per-disk tokens** - Hosts with multiple encrypted disks need separate Clevis tokens
4. **Programmatic management** - Scripts must be able to differentiate and auto-provision

## Architecture

### 1. Initrd SSH Private Keys

**Storage:** SOPS-encrypted in nix-secrets per-host secrets file

```yaml
# nix-secrets/sops/anguish.yaml
initrd:
  ssh_host_ed25519_key: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    [SOPS-ENCRYPTED CONTENT]
    -----END OPENSSH PRIVATE KEY-----
```

**Public keys:** Can be stored in plain text (no secrets)
- Location: `nix-secrets/ssh/initrd-public/<hostname>_initrd_ed25519.pub`
- Used for: Documenting fingerprints, TOFU verification

**Deployment workflow:**

1. **Generation (during vm-fresh/install):**
   ```bash
   # Generate key pair locally
   ssh-keygen -t ed25519 -f /tmp/initrd_key -N ""

   # Encrypt private key with SOPS
   sops --set '["initrd"]["ssh_host_ed25519_key"] "'$(cat /tmp/initrd_key)'"' \
     ../nix-secrets/sops/<hostname>.yaml

   # Store public key for reference
   cp /tmp/initrd_key.pub ../nix-secrets/ssh/initrd-public/<hostname>_initrd_ed25519.pub

   # Commit and push
   git add sops/<hostname>.yaml ssh/initrd-public/
   git commit -m "feat: add <hostname> initrd SSH key (SOPS-encrypted)"
   ```

2. **Deployment to target (via --extra-files):**
   ```bash
   # Decrypt with SOPS
   INITRD_KEY=$(sops --extract '["initrd"]["ssh_host_ed25519_key"]' \
     ../nix-secrets/sops/<hostname>.yaml)

   # Place in --extra-files
   echo "$INITRD_KEY" > "$EXTRA_FILES/persist/etc/ssh/initrd_ssh_host_ed25519_key"
   chmod 600 "$EXTRA_FILES/persist/etc/ssh/initrd_ssh_host_ed25519_key"

   # nixos-anywhere deploys to /persist/etc/ssh/
   ```

3. **Runtime on target:**
   - Private key exists at `/persist/etc/ssh/initrd_ssh_host_ed25519_key`
   - Entire drive is encrypted, so key is protected at rest
   - bcachefs-unlock.nix copies key into initrd at build time

4. **Rebuilds:**
   - Key already in `/persist/etc/ssh/` (persists across rebuilds)
   - bcachefs-unlock.nix copies from persist into initrd
   - No SOPS decryption needed during rebuild (key already on disk)

### 2. Clevis JWE Tokens

**Question for user:** The Clevis JWE token is already TPM-encrypted. Can it only be decrypted by the specific TPM hardware?

**If YES** (token can ONLY be decrypted by the bound TPM):
- Storing in plain text is acceptable
- Token is useless without physical access to the TPM
- Can store in: `nix-secrets/clevis/<hostname>-<disk>.jwe` (plain text)

**If NO** (token could be used to unlock drive if obtained):
- **Must be SOPS-encrypted**
- Storage location: `sops/<hostname>.yaml` under `clevis/<disk>/token`

**Proposed secure approach (assuming worst case - encrypt everything):**

```yaml
# nix-secrets/sops/anguish.yaml
clevis:
  bcachefs-root:
    token: |
      {
        "protected": "...",
        "encrypted_key": "...",
        "iv": "...",
        "ciphertext": "...",
        "tag": "..."
      }
```

**Per-host, per-disk naming:**
- `bcachefs-root` - Root filesystem
- `bcachefs-data` - Data filesystem (if separate)
- Format: `<filesystem-type>-<mountpoint-name>`

**Deployment workflow:**

1. **Generation (after first boot):**
   ```bash
   # On target machine, after first boot
   DISK_PASSWORD=$(sops --extract '["disk"]["password"]' /run/secrets/shared.yaml)

   # Generate Clevis token bound to TPM
   TOKEN=$(echo "$DISK_PASSWORD" | clevis encrypt tpm2 '{"pcr_ids":"0,7"}')

   # Save to /persist
   echo "$TOKEN" > /persist/etc/clevis/bcachefs-root.jwe
   chmod 600 /persist/etc/clevis/bcachefs-root.jwe

   # Encrypt and store in nix-secrets
   sops --set "$(cat <<EOF
     [\"clevis\"][\"bcachefs-root\"][\"token\"] '$TOKEN'
   EOF
   )" ../nix-secrets/sops/<hostname>.yaml

   # Commit and push
   git add sops/<hostname>.yaml
   git commit -m "feat: add <hostname> Clevis TPM token for bcachefs-root"
   ```

2. **Rebuilds:**
   - Token already in `/persist/etc/clevis/bcachefs-root.jwe`
   - bcachefs-unlock.nix copies from persist into initrd
   - No SOPS decryption needed (token persists on disk)

3. **Fresh install (if token pre-exists in nix-secrets):**
   ```bash
   # Decrypt token from SOPS
   TOKEN=$(sops --extract '["clevis"]["bcachefs-root"]["token"]' \
     ../nix-secrets/sops/<hostname>.yaml)

   # Place in --extra-files
   echo "$TOKEN" > "$EXTRA_FILES/persist/etc/clevis/bcachefs-root.jwe"
   chmod 600 "$EXTRA_FILES/persist/etc/clevis/bcachefs-root.jwe"
   ```

### 3. Updated File Structure

```
nix-secrets/
├── sops/
│   ├── shared.yaml              # Shared secrets (disk password, etc.)
│   └── anguish.yaml             # Per-host secrets
│       ├── initrd:
│       │   └── ssh_host_ed25519_key: "..."  # SOPS-encrypted private key
│       └── clevis:
│           └── bcachefs-root:
│               └── token: "{...}"            # SOPS-encrypted JWE token
│
└── ssh/
    └── initrd-public/           # Plain text public keys (no secrets)
        └── anguish_initrd_ed25519.pub
```

### 4. bcachefs-unlock.nix Changes

Current approach (WRONG - expects plain text in nix-secrets):
```nix
initrdSshKeySource = "${inputs.nix-secrets}/ssh/initrd/${hostName}_initrd_ed25519";
```

**New approach (CORRECT - uses SOPS-deployed key from persist):**
```nix
initrdSshKeySource = "${hostCfg.persistFolder}/etc/ssh/initrd_ssh_host_ed25519_key";
clevisTokenSource = "${hostCfg.persistFolder}/etc/clevis/bcachefs-root.jwe";
```

The module copies from `/persist` (where SOPS or --extra-files deployed them) into initrd.

### 5. Security Benefits

✅ **Private keys never in plain text in git**
✅ **SOPS-encrypted at rest in nix-secrets repo**
✅ **Encrypted on disk (bcachefs encryption protects /persist)**
✅ **Per-host isolation** (each host has unique keys)
✅ **Per-disk tokens** (multiple disks supported)
✅ **Programmatic management** (scripts can parse YAML structure)
✅ **Build-time safety** (nix store never contains secrets)

### 6. Questions for User

1. **Clevis token security:** Can the JWE token unlock the drive if someone obtains it without the TPM hardware? Or is it truly TPM-bound?
   - If TPM-bound only: Plain text storage acceptable
   - If not TPM-bound: MUST be SOPS-encrypted

2. **Multiple disks:** Should we support naming like:
   - `clevis/bcachefs-root/token` for `/`
   - `clevis/bcachefs-data/token` for `/data`
   - Or use device paths: `clevis/dev-vda2/token`?

3. **Public key storage:** Should we keep public keys in `ssh/initrd-public/` for reference, or just rely on SOPS?

## Implementation Order

1. ✅ Remove plain text secrets from nix-secrets
2. ⏭️ Update vm-fresh to generate and SOPS-encrypt initrd keys
3. ⏭️ Update bcachefs-unlock.nix to use keys from /persist
4. ⏭️ Create helper script for Clevis token management
5. ⏭️ Test full workflow on anguish VM
6. ⏭️ Document the secure workflow
