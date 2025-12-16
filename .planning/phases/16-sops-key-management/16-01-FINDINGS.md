# SOPS/Age Key Management Research Findings

## Executive Summary

This document captures the current state of SOPS/age key management in this NixOS configuration as of 2025-12-15. The configuration uses sops-nix for secrets management with age encryption, implements a role-based secret category system, and manages secrets through a separate private repository (nix-secrets). The implementation is mature but lacks automated key rotation enforcement and formal key lifecycle management.

## Current Architecture

### 1. SOPS-nix Configuration

**Primary Configuration**: `/home/rain/nix-config/modules/common/sops.nix`

```nix
sops = {
  age = {
    keyFile = "/var/lib/sops-nix/key.txt";
    sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    generateKey = true;
  };
};
```

**Key Characteristics**:
- **Key Generation**: `generateKey = true` - sops-nix automatically generates age keys on first boot
- **Primary Key Location**: `/var/lib/sops-nix/key.txt` - host-specific age key derived from SSH host key
- **SSH Fallback**: SSH host key at `/etc/ssh/ssh_host_ed25519_key` used as recipient via ssh-to-age conversion
- **User Age Keys**: User-level keys stored in `~/.config/sops/age/keys.txt` (created from `keys/age` secret in host's YAML)
- **Flake Integration**: sops-nix imported at flake level for all hosts (`flake.nix:81`)

**Imports**:
- Module is part of common configuration, imported for all hosts
- No per-host `defaultSopsFile` configuration (comment indicates it should be in `hosts/common/core/sops.nix` which doesn't exist)

### 2. Secret File Organization

**External Repository**: Secrets stored in private repo `github.com:fullstopslash/snowflake-secrets.git` (branch: `simple`)

**File Structure** (inferred from usage):
```
nix-secrets/
├── .sops.yaml              # Creation rules and recipient keys
└── sops/
    ├── shared.yaml         # Cross-host secrets (passwords, msmtp, etc.)
    └── <hostname>.yaml     # Per-host secrets (age keys, host-specific)
```

**Secret Categories** (defined in `/home/rain/nix-config/modules/common/host-spec.nix:235-267`):
- **base** (default: true) - User passwords, age keys, msmtp (all roles)
- **desktop** (default: false) - Home Assistant credentials (desktop/laptop/tablet)
- **server** (default: false) - Backup credentials, service secrets (server role)
- **network** (default: false) - Tailscale OAuth, VPN (desktop/laptop/server/pi)
- **cli** (default: false) - Atuin credentials (desktop/laptop/server)

**Role-Based Secret Assignment** (example from `/home/rain/nix-config/roles/common.nix:65-67`):
```nix
secretCategories = {
  base = lib.mkDefault true;
};
```

Additional categories set by specific roles (e.g., form-desktop.nix sets desktop=true, network=true, cli=true).

### 3. Key Storage and Generation Behavior

**Host Age Keys**:
- **Generation Method**: Derived from SSH host key using `ssh-to-age`
- **Storage**: `/var/lib/sops-nix/key.txt` (private key)
- **Public Key**: Derived from `/etc/ssh/ssh_host_ed25519_key.pub`
- **Registration**: Added to nix-secrets `.sops.yaml` during bootstrap

**User Age Keys**:
- **Generation**: Created during bootstrap via `age-keygen` (`scripts/helpers.sh:142`)
- **Storage**:
  - Private: Encrypted in host's `sops/<hostname>.yaml` under `keys/age`
  - Deployed: Symlinked to `~/.config/sops/age/keys.txt` by sops-nix
- **Purpose**: Home-manager level secrets decryption

**SSH Key for Non-Yubikey Hosts** (`modules/services/networking/ssh.nix:33-38`):
```nix
sops.secrets = lib.mkIf (cfg.deployUserKey && config.hostSpec.hasSecrets) {
  "keys/ssh/ed25519" = {
    sopsFile = "${sopsFolder}/shared.yaml";
    owner = config.hostSpec.primaryUsername;
    mode = "0400";
  };
};
```
- Deployed from SOPS for hosts without Yubikey
- Symlinked by chezmoi to `~/.ssh/id_ed25519`

**No Key Rotation**: `generateKey = true` runs only once; no automated rotation mechanism exists.

## Key Lifecycle

### 1. Bootstrap Process for New Hosts

**Automated Bootstrap**: `/home/rain/nix-config/scripts/bootstrap-nixos.sh`

**Process Flow**:
1. **nixos-anywhere Installation** (lines 133-205):
   - Pre-generates SSH host key in temp directory
   - Installs NixOS via nixos-anywhere
   - SSH host key placed in `/etc/ssh/` (or `/persist/etc/ssh/` for impermanence)

2. **Age Key Generation** (lines 207-239):
   - Scans SSH host key from newly installed system
   - Converts to age public key via `ssh-to-age`
   - Updates `.sops.yaml` via `sops_update_age_key` helper

3. **User Age Key Setup** (lines 301-309):
   - Calls `sops_setup_user_age_key` from helpers.sh
   - Generates new age keypair
   - Stores private key encrypted in `sops/<hostname>.yaml`
   - Adds public key to `.sops.yaml`

4. **Creation Rules Update** (lines 311-318):
   - Adds host and user keys to shared.yaml creation rules
   - Creates per-host YAML creation rules
   - Rekeys all secrets: `just rekey`
   - Updates flake input: `nix flake update nix-secrets`

5. **Config Deployment** (lines 321-342):
   - Copies nix-config and nix-secrets to target
   - Optional immediate rebuild

**Manual Bootstrap Path** (documented in `docs/addnewhost.md:98-157`):
- Generate SSH host key manually
- Convert to age key
- Manually edit `.sops.yaml`
- Create empty host secrets file
- Add to shared.yaml rules
- Rekey secrets
- Generate user age key

### 2. Recipient Management in .sops.yaml

**Location**: `../nix-secrets/.sops.yaml` (relative to nix-config)

**Structure** (inferred from helpers.sh):
```yaml
keys:
  hosts:
    - &hostname age1xxxxxxxxx...
  users:
    - &user_hostname age1xxxxxxxxx...

creation_rules:
  - path_regex: shared\.yaml$
    key_groups:
      - age:
        - *user_hostname
        - *hostname

  - path_regex: hostname\.yaml$
    key_groups:
      - age:
        - *user_hostname
        - *hostname
```

**Key Management Helpers** (`scripts/helpers.sh:60-179`):
- `sops_update_age_key`: Add/update keys in .sops.yaml
- `sops_add_shared_creation_rules`: Add host to shared.yaml access
- `sops_add_host_creation_rules`: Create per-host YAML rules
- `sops_generate_user_age_key`: Generate and register user keys
- `sops_setup_user_age_key`: Complete user key setup flow

**Rekey Process** (`justfile:490-499`):
```bash
just rekey
# Runs: sops updatekeys -y for all sops/*.yaml files
# Commits changes with message "chore: rekey"
# Pushes to GitHub
```

### 3. Current Rotation Capabilities

**NONE - No automated rotation exists**

Evidence:
- No scheduled rotation jobs in systemd
- No rotation-related code in modules
- `TODO.md:371` mentions "Automatic scheduled sops rotate" as future work (Stage 10.x)
- `generateKey = true` runs once at first boot, never again

**Manual Rotation Would Require**:
1. Generate new age key on host
2. Update `.sops.yaml` with new public key
3. Rekey all secrets with `just rekey`
4. Update flake input on all hosts
5. Rebuild all hosts to get new keys

## Integration Patterns

### 1. Module Secret Declaration

**Common Pattern** (from modules like tailscale.nix, atuin.nix, borg.nix):
```nix
sops.secrets = {
  "path/to/secret" = {
    sopsFile = "${sopsFolder}/shared.yaml";  # or host-specific .yaml
    owner = "username";
    group = "groupname";
    mode = "0400";
    path = "/custom/path";  # optional, defaults to /run/secrets/<key>
  };
};
```

**Key Attributes**:
- `sopsFile`: Which encrypted YAML file contains the secret
- `owner`/`group`/`mode`: File permissions after decryption
- `path`: Custom location (defaults to `/run/secrets/<secret-name>`)
- `neededForUsers`: Special flag for user password secrets (places in `/run/secrets-for-users/`)

**Template Usage** (`modules/services/desktop/common.nix:128-135`):
```nix
sops.templates."post-sleep-samsung.env" = {
  content = ''
    HASS_SERVER=${config.sops.placeholder."env_hass_server"}
    HASS_TOKEN=${config.sops.placeholder."env_hass_token"}
  '';
  owner = config.hostSpec.username;
  mode = "0400";
};
```
- Templates combine multiple secrets into environment files
- Used with `EnvironmentFile` in systemd services

### 2. Systemd Dependencies on SOPS Secrets

**Boot-Time Requirements**:
- **User Passwords** (`modules/users/default.nix:44-58`):
  ```nix
  hashedPasswordFile = config.sops.secrets."passwords/${user}".path;
  ```
  - Uses `neededForUsers = true` flag
  - Required before user creation during activation
  - Blocks boot if decryption fails

**Service Dependencies** (common patterns):
```nix
systemd.services.example = {
  after = [ "sops-nix.service" ];  # Wait for secret decryption
  serviceConfig = {
    EnvironmentFile = config.sops.secrets."secret".path;
  };
};
```

**Observed in**:
- **atuin-autologin** (`modules/services/cli/atuin.nix:89`): Explicitly waits for sops-nix
- **bitwarden-autologin** (`modules/services/security/bitwarden.nix:210`): No explicit dependency, checks file existence
- **tailscale-oauth-key** (`modules/services/networking/tailscale.nix:104`): No explicit dependency, reads from config.sops paths

**Secret Availability**:
- Secrets decrypted to `/run/secrets/` (tmpfs)
- User secrets in `/run/secrets-for-users/` (for neededForUsers)
- Available after sops-nix.service activation
- Persist only in RAM (lost on reboot, re-decrypted on boot)

### 3. Boot-Time Secret Requirements

**Critical Path**:
1. System boot
2. `/etc/ssh/ssh_host_ed25519_key` must exist (pre-installed or from /persist)
3. `/var/lib/sops-nix/key.txt` generated if missing (from SSH key)
4. sops-nix.service activates
5. Secrets decrypted to /run/secrets/
6. User creation proceeds (with password hashes)
7. Services start (with secrets available)

**Failure Modes**:
- Missing SSH host key → age key generation fails → no secrets
- Host key not in `.sops.yaml` → decryption fails → secrets unavailable
- Missing user age key → home-manager secrets fail

**Verification Tool**: `/home/rain/nix-config/scripts/check-sops.sh`
- Checks SSH host key exists
- Validates user age key format
- Verifies sops-nix activation
- Lists decrypted secrets in /run/secrets

### 4. Error Handling When Secrets Missing

**Common Patterns**:

**Graceful Degradation** (`modules/services/security/bitwarden.nix:33-37`):
```nix
if [ ! -r "$SECRET_FILE" ]; then
  echo "Secrets not available yet (may be during rebuild), skipping..." 1>&2
  exit 0
fi
```

**Hard Failure** (`modules/services/cli/atuin.nix:118-121`):
```nix
if [ ! -f "$USERNAME_FILE" ]; then
  echo "Username not found (SOPS secret not deployed yet)"
  exit 1  # Triggers service restart
fi
```

**Conditional Secret Loading** (`modules/users/default.nix:44-48`):
```nix
sopsHashedPasswordFile =
  if config.hostSpec.hasSecrets && !config.hostSpec.isMinimal then
    config.sops.secrets."passwords/${user}".path
  else
    null;
```

**Module-Level Guards**:
- `lib.mkIf config.hostSpec.hasSecrets` - Only enable secrets if host has them
- `lib.mkIf hasDesktopSecrets` - Category-based secret enablement
- No global error handling for missing secrets

## Identified Gaps

### 1. Missing Enforcement Mechanisms

**No Permission/Ownership Validation**:
- Secrets created with specified owner/mode, but no runtime checks
- No verification that `/var/lib/sops-nix/key.txt` is mode 0600
- No assertion that SSH host keys are properly protected
- No checking that decrypted secrets in /run/secrets have correct permissions

**No Age Key Format Validation**:
- `check-sops.sh` validates format, but only as manual check
- No NixOS module to enforce key format at evaluation time
- No systemd assertion to block boot on invalid keys

**No Creation Rules Enforcement**:
- `.sops.yaml` could be malformed, only discovered at runtime
- No validation that host keys are actually in creation rules
- No check that shared.yaml includes required hosts

**No Secret File Existence Checks**:
- Modules assume secrets exist in sopsFile
- Failures only occur at runtime when sops-nix tries to decrypt
- No evaluation-time warnings for missing secrets

### 2. Manual Steps in Key Lifecycle

**Bootstrap Process**:
- Script is automated, but requires manual execution
- User must remember to run bootstrap-nixos.sh
- No integration with nixos-anywhere directly
- Manual `.sops.yaml` editing if script fails

**Adding New Host**:
- Must manually add to shared.yaml creation rules
- Must manually rekey all secrets
- Must manually update flake on all hosts
- No automatic propagation of key changes

**Secret Addition**:
- Manual editing of `.sops.yaml` creation rules
- Manual `sops -e -i <file>` to add new secrets
- Manual rekey and flake update
- No declarative secret schema

**Key Verification**:
- Manual run of `check-sops.sh --verbose`
- No automated validation in CI/CD
- No pre-rebuild checks

### 3. Rotation Process (Missing)

**No Scheduled Rotation**:
- No systemd timers for key rotation
- No automation to rotate age keys
- No process to rotate SSH host keys
- No coordination of rotation across multiple hosts

**No Rotation Tooling**:
- No command to rotate single host key
- No command to rotate user age key
- No verification that old keys are removed
- No rollback mechanism if rotation fails

**No Rotation Policy**:
- No defined rotation schedule (90 days? 1 year?)
- No tracking of key age
- No warning when keys are old
- No enforcement of rotation deadlines

**Manual Rotation Would Require**:
1. Generate new age key on host
2. Add new key to `.sops.yaml` (keeping old key)
3. Rekey all secrets with both keys
4. Deploy to host
5. Verify new key works
6. Remove old key from `.sops.yaml`
7. Rekey again (without old key)
8. Deploy to all hosts again

### 4. Missing Monitoring and Auditing

**No Key Age Tracking**:
- No record of when keys were generated
- No logging of key usage
- No alerts for old keys

**No Decryption Audit**:
- No logging of which secrets were decrypted
- No tracking of secret access
- No detection of unauthorized access attempts

**No Health Checks**:
- No monitoring that sops-nix activates successfully
- No alerts if secret decryption fails
- No verification that secrets are available to services

**No Inventory**:
- No central list of all age keys
- No mapping of keys to hosts
- No tracking of which secrets each host can access

## Architecture Alignment

### 1. Patterns That Align With Repo Principles

**Filesystem-Driven Modules**:
- ✅ Secret categories map to `hostSpec.secretCategories.*`
- ✅ Modules self-declare their secret dependencies
- ✅ Role-based secret access follows module selection patterns

**Role-Based Configuration**:
- ✅ Roles set `secretCategories` via `lib.mkDefault`
- ✅ Hosts can override role defaults
- ✅ Explicit secret requirements per role (documented in helpers.sh:181-240)

**Lib.mkDefault Override System**:
- ✅ `secretCategories` all use `lib.mkDefault`
- ✅ Hosts can override `hasSecrets = false`
- ✅ Modules respect `config.hostSpec.secretCategories.*`

**Explicit Over Implicit**:
- ✅ Modules explicitly declare `sopsFile = "${sopsFolder}/shared.yaml"`
- ✅ No hidden secret loading
- ✅ Clear documentation of secret categories per role

**Version Control (Jujutsu)**:
- ⚠️ Bootstrap script uses git commands (not jj)
- ⚠️ justfile rekey uses git add/commit/push
- ⚠️ Could be adapted to jj via wrapper functions

### 2. What Needs to Change for Filesystem-Driven Modules

**Current State**:
- Secrets managed in external repo (nix-secrets)
- `.sops.yaml` is external to nix-config
- No module at `modules/security/sops/` or similar

**Proposed Changes**:
1. **Create Security Module Category**:
   ```
   modules/security/
   ├── sops-enforcement.nix   # Key validation, permission checks
   └── sops-rotation.nix      # Automated rotation (future)
   ```

2. **Make Enforcement Discoverable**:
   - Module at `modules/security/sops-enforcement.nix`
   - Auto-enabled when `hostSpec.hasSecrets = true`
   - No manual imports required

3. **Integrate with Host-Spec**:
   ```nix
   # In modules/common/host-spec.nix
   sopsEnforcement = {
     validateKeyPermissions = lib.mkDefault true;
     validateKeyFormat = lib.mkDefault true;
     requireCreationRules = lib.mkDefault true;
   };
   ```

### 3. Integration With Role System and lib.mkDefault

**Current Integration** (works well):
```nix
# roles/form-desktop.nix
secretCategories = {
  base = lib.mkDefault true;
  desktop = lib.mkDefault true;
  network = lib.mkDefault true;
  cli = lib.mkDefault true;
};
```

**Proposed Additions** (for enforcement):
```nix
# roles/form-server.nix (example)
sopsEnforcement = {
  rotationSchedule = lib.mkDefault "monthly";  # server keys rotated monthly
  validateBackupSecrets = lib.mkDefault true;  # check borg secrets exist
};
```

**Benefits**:
- Roles can set different enforcement policies
- Hosts can override via non-mkDefault values
- Maintains explicit configuration philosophy

## Recommendations

### 1. Module Structure for Enforcement

**Create**: `/home/rain/nix-config/modules/security/sops-enforcement.nix`

**Purpose**: Enforce SOPS key hygiene at system activation time

**Recommended Checks**:
```nix
{
  config = lib.mkIf config.hostSpec.hasSecrets {

    # Assertion: SSH host key exists and has correct permissions
    assertions = [
      {
        assertion = builtins.pathExists /etc/ssh/ssh_host_ed25519_key;
        message = "SSH host key missing at /etc/ssh/ssh_host_ed25519_key";
      }
    ];

    # Activation script: Validate key permissions
    system.activationScripts.sopsKeyValidation = ''
      # Check /var/lib/sops-nix/key.txt permissions
      if [ -f /var/lib/sops-nix/key.txt ]; then
        perms=$(stat -c %a /var/lib/sops-nix/key.txt)
        if [ "$perms" != "600" ]; then
          echo "WARNING: Age key has incorrect permissions ($perms), fixing..."
          chmod 600 /var/lib/sops-nix/key.txt
        fi
      fi

      # Check SSH host key permissions
      if [ -f /etc/ssh/ssh_host_ed25519_key ]; then
        perms=$(stat -c %a /etc/ssh/ssh_host_ed25519_key)
        if [ "$perms" != "600" ]; then
          echo "WARNING: SSH host key has incorrect permissions ($perms), fixing..."
          chmod 600 /etc/ssh/ssh_host_ed25519_key
        fi
      fi
    '';

    # Systemd service: Verify secrets decrypted successfully
    systemd.services.sops-verification = {
      description = "Verify SOPS secrets decrypted successfully";
      after = [ "sops-nix.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.writeShellScript "sops-verify" ''
          #!/usr/bin/env bash
          set -e

          # Check that expected secrets exist
          if [ -d /run/secrets ]; then
            secret_count=$(find /run/secrets -type f | wc -l)
            if [ "$secret_count" -eq 0 ]; then
              echo "ERROR: No secrets found in /run/secrets" >&2
              exit 1
            fi
            echo "Found $secret_count secrets in /run/secrets"
          else
            echo "ERROR: /run/secrets does not exist" >&2
            exit 1
          fi
        ''}";
      };
    };
  };
}
```

**Integration Point**: Add to `modules/security/default.nix` imports

### 2. Integration With Existing modules/common/sops.nix

**Current**: `/home/rain/nix-config/modules/common/sops.nix` sets base configuration

**Proposed Enhancement**:
```nix
# modules/common/sops.nix
{
  sops = {
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      generateKey = true;
    };

    # NEW: Validation settings
    validateSopsFiles = lib.mkDefault true;

    # NEW: Key age tracking (for future rotation)
    secrets."sops/key-generated-at" = lib.mkIf config.hostSpec.hasSecrets {
      sopsFile = "${sopsFolder}/${config.networking.hostName}.yaml";
      mode = "0400";
    };
  };

  # Import enforcement module when secrets are enabled
  imports = lib.optional config.hostSpec.hasSecrets
    (lib.custom.relativeToRoot "modules/security/sops-enforcement.nix");
}
```

**Benefits**:
- Enforcement auto-enabled with secrets
- No manual imports required
- Follows existing module pattern

### 3. Jujutsu Workflow for Key Rotation

**Problem**: Current workflow uses git commands in bootstrap and justfile

**Solution**: Create jj-compatible wrapper functions

**Create**: `/home/rain/nix-config/scripts/vcs-helpers.sh`

```bash
# Version control abstraction for git/jj
VCS_TYPE=${VCS_TYPE:-jj}  # or 'git'

function vcs_add() {
  if [ "$VCS_TYPE" = "jj" ]; then
    # jj automatically tracks changes, no explicit add needed
    :
  else
    git add "$@"
  fi
}

function vcs_commit() {
  local message="$1"
  if [ "$VCS_TYPE" = "jj" ]; then
    jj commit -m "$message"
  else
    git commit -m "$message"
  fi
}

function vcs_push() {
  if [ "$VCS_TYPE" = "jj" ]; then
    jj git push
  else
    git push
  fi
}
```

**Update justfile**:
```just
rekey: sops-rekey
  cd ../nix-secrets && \
    source ../nix-config/scripts/vcs-helpers.sh && \
    vcs_add -u && (vcs_commit "chore: rekey" || true) && vcs_push
```

**Benefits**:
- Works with both git and jujutsu
- Single change point for VCS commands
- Respects $VCS_TYPE environment variable

### 4. Testing Strategy Using griefling VM

**Current VM**: `hosts/griefling/default.nix` - Desktop VM for testing

**Proposed Test Suite**:

**Create**: `/home/rain/nix-config/tests/sops-enforcement.bats` (if using bats)

```bash
#!/usr/bin/env bats

@test "SOPS: Age key exists with correct permissions" {
  run stat -c %a /var/lib/sops-nix/key.txt
  [ "$status" -eq 0 ]
  [ "$output" = "600" ]
}

@test "SOPS: SSH host key exists with correct permissions" {
  run stat -c %a /etc/ssh/ssh_host_ed25519_key
  [ "$status" -eq 0 ]
  [ "$output" = "600" ]
}

@test "SOPS: Secrets decrypted to /run/secrets" {
  run sh -c "find /run/secrets -type f | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" -gt 0 ]
}

@test "SOPS: User age key has valid format" {
  run grep -c "^AGE-SECRET-KEY-" ~/.config/sops/age/keys.txt
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "SOPS: sops-nix service activated successfully" {
  run systemctl is-active sops-nix.service
  [ "$status" -eq 0 ]
}
```

**Integration with VM workflow** (`justfile`):

```just
# Test SOPS enforcement on griefling VM
vm-test-sops HOST="griefling":
  @echo "Running SOPS enforcement tests on {{HOST}}..."
  ssh {{HOST}} 'bash -s' < tests/sops-enforcement.sh
```

**Testing Flow**:
1. Build griefling VM: `just vm-rebuild griefling`
2. Run SOPS tests: `just vm-test-sops griefling`
3. Verify enforcement module works correctly
4. Test key rotation scenarios (future)

**Key Test Scenarios**:
- ✅ Fresh VM boot with generated keys
- ✅ Secret decryption succeeds
- ✅ Permission enforcement works
- ⏸️ Key rotation workflow (future)
- ⏸️ Recovery from missing keys (future)

## Appendices

### A. File References

**Core SOPS Configuration**:
- `/home/rain/nix-config/modules/common/sops.nix` - Base sops-nix setup
- `/home/rain/nix-config/modules/common/host-spec.nix:235-267` - Secret categories definition
- `/home/rain/nix-config/flake.nix:79-81` - sops-nix module import

**Secret-Using Modules**:
- `/home/rain/nix-config/modules/services/networking/tailscale.nix:24-39` - Tailscale OAuth secrets
- `/home/rain/nix-config/modules/services/networking/ssh.nix:33-38` - SSH key deployment
- `/home/rain/nix-config/modules/services/storage/borg.nix:493-509` - Borg backup secrets
- `/home/rain/nix-config/modules/services/security/bitwarden.nix:184-205` - Bitwarden automation
- `/home/rain/nix-config/modules/services/cli/atuin.nix:49-73` - Atuin credentials
- `/home/rain/nix-config/modules/services/desktop/common.nix:118-135` - Home Assistant secrets
- `/home/rain/nix-config/modules/users/default.nix:44-96` - User passwords

**Bootstrap and Helpers**:
- `/home/rain/nix-config/scripts/bootstrap-nixos.sh` - Automated host bootstrap
- `/home/rain/nix-config/scripts/helpers.sh:60-292` - SOPS helper functions
- `/home/rain/nix-config/scripts/check-sops.sh` - Secret verification tool
- `/home/rain/nix-config/justfile:1, 490-530` - Rekey and SOPS management

**Roles**:
- `/home/rain/nix-config/roles/common.nix:65-67` - Base secret categories
- `/home/rain/nix-config/roles/form-desktop.nix:75-81` - Desktop secret categories
- `/home/rain/nix-config/roles/form-server.nix:66-72` - Server secret categories
- `/home/rain/nix-config/roles/form-vm.nix:102-105` - VM secret categories

**Documentation**:
- `/home/rain/nix-config/docs/addnewhost.md` - New host setup guide
- `/home/rain/nix-config/docs/secretsmgmt.md` - Secrets management (external link)
- `/home/rain/nix-config/docs/TODO.md:371` - Future rotation work

**Planning Documents**:
- `/home/rain/nix-config/.planning/phases/04-secrets-security/04-04-SUMMARY.md` - Shared secrets implementation
- `/home/rain/nix-config/.planning/phases/16-sops-key-management/16-01-RESEARCH.md` - This research prompt

### B. Secret Category to File Mapping

**Base Category** (`secretCategories.base = true`):
- `passwords/<username>` → `sops/shared.yaml` (neededForUsers)
- `passwords/msmtp` → `sops/shared.yaml`
- `keys/age` → `sops/<hostname>.yaml`

**Desktop Category** (`secretCategories.desktop = true`):
- `env_hass_server` → `sops/shared.yaml`
- `env_hass_token` → `sops/shared.yaml`

**Server Category** (`secretCategories.server = true`):
- `passwords/borg` → `sops/shared.yaml`
- `keys/ssh/borg` → `sops/shared.yaml`

**Network Category** (`secretCategories.network = true`):
- `tailscale/oauth_client_id` → `sops/shared.yaml`
- `tailscale/oauth_client_secret` → `sops/shared.yaml`
- `keys/ssh/ed25519` → `sops/shared.yaml` (non-Yubikey hosts)

**CLI Category** (`secretCategories.cli = true`):
- `atuin/username` → `sops/shared.yaml`
- `atuin/password` → `sops/shared.yaml`
- `atuin/key` → `sops/shared.yaml`
- `atuin/sync_address` → `sops/shared.yaml`

**Additional Secrets** (module-specific):
- `bitwarden/*` → `sops/shared.yaml` (when bitwarden module enabled)

### C. Bootstrap Command Examples

**Full Automated Bootstrap**:
```bash
./scripts/bootstrap-nixos.sh \
  -n newhostname \
  -d 192.168.1.100 \
  -k ~/.ssh/id_ed25519
```

**VM Bootstrap via Justfile**:
```bash
# Create VM, install NixOS, setup secrets, rebuild
just vm-create-and-bootstrap griefling

# Or step-by-step:
just vm-create griefling              # Create and install
just vm-setup-age-key griefling       # Setup age key
just vm-register-age-key griefling    # Register in nix-secrets
just vm-rebuild griefling             # Rebuild with secrets
```

**Manual Key Registration**:
```bash
# Get host age public key
ssh hostname "cat /var/lib/sops-nix/key.txt | age-keygen -y"

# Update .sops.yaml
just sops-update-host-age-key hostname age1xxxxx...

# Add creation rules
just sops-add-creation-rules rain hostname

# Rekey and push
just rekey
```

### D. Key Rotation Scenario (Future Implementation)

**Proposed Rotation Flow**:

1. **Generate New Key**:
   ```bash
   # On target host
   ssh hostname "age-keygen -o /tmp/new-age-key.txt"
   NEW_PUBKEY=$(ssh hostname "age-keygen -y /tmp/new-age-key.txt")
   ```

2. **Add to .sops.yaml** (keeping old key):
   ```bash
   just sops-update-host-age-key hostname "$NEW_PUBKEY"
   ```

3. **Rekey with Both Keys**:
   ```bash
   just rekey  # Now encrypted with both old and new keys
   ```

4. **Deploy New Key**:
   ```bash
   ssh hostname "sudo cp /tmp/new-age-key.txt /var/lib/sops-nix/key.txt"
   ssh hostname "sudo chmod 600 /var/lib/sops-nix/key.txt"
   ssh hostname "sudo nixos-rebuild switch"
   ```

5. **Verify New Key Works**:
   ```bash
   ssh hostname "sudo systemctl status sops-nix.service"
   ssh hostname "ls -la /run/secrets/"
   ```

6. **Remove Old Key** from `.sops.yaml`:
   ```bash
   # Manual edit to remove old key anchor
   vim ../nix-secrets/.sops.yaml
   ```

7. **Final Rekey** (without old key):
   ```bash
   just rekey
   ```

**Automation Needed**:
- Script to orchestrate full rotation
- Verification that new key works before removing old
- Rollback capability if rotation fails
- Logging of rotation events

---

**Document Status**: Complete
**Date**: 2025-12-15
**Next Phase**: 16-02-PLAN.md (design enforcement and rotation mechanisms)
