# SSH/GitHub Authentication System Audit

**Date**: 2026-01-03
**Host**: griefling (VM)
**Purpose**: Comprehensive audit to identify why GitHub authentication, repository cloning, and chezmoi deployment are failing on fresh installs

## Executive Summary

The SSH/GitHub authentication system is **completely non-functional** on griefling. Critical findings:

1. **NO SSH keys deployed** - User ~/.ssh/ directory doesn't exist
2. **NO SOPS secrets deployed** - No deploy keys, no user SSH key, sops-nix.service doesn't exist
3. **github-repos-init service failed** - Cannot find ssh executable, no deploy keys available
4. **Module not configured correctly** - Module may not be enabled or SOPS configuration missing
5. **Repos manually cloned** - nix-config and nix-secrets exist but were cloned manually (not via automation)
6. **chezmoi not cloned** - Repository directory exists but is empty

## Root Cause Analysis

### Primary Issue: SOPS Secrets Not Deployed

The `sops-nix.service` **does not exist** on the system, which means:
- No SOPS secrets are being decrypted
- No deploy keys are available at `/run/secrets/deploy-keys/*`
- No user SSH key is available
- The entire secret deployment chain is broken

**Why this matters**: The github-repos.nix module depends on SOPS to deploy deploy keys. Without SOPS working, the module cannot function.

### Secondary Issue: Module Configuration

The module enablement check failed with error:
```
error: flake 'git+file:///home/rain/nix-config' does not provide attribute
'packages.x86_64-linux.nixosConfigurations.griefling.config.myModules.services.development.github-repos.enable'
Did you mean githubRepos?
```

This suggests either:
1. The module path has changed (camelCase vs kebab-case naming)
2. The module is not properly registered in the selection system
3. The attribute path is incorrect

### Tertiary Issue: Missing SSH Executable

Service logs show:
```
error: cannot run ssh: No such file or directory
fatal: unable to fork
```

The systemd service doesn't have `openssh` in its PATH, even though it's declared in the module.

## Detailed Findings

### 1. SSH Key Locations

**User SSH directory** (~/.ssh/):
- **Status**: Does not exist
- **Expected**: Directory should exist with deploy keys and user SSH key
- **Impact**: No SSH authentication possible for user

**Root SSH directory** (/root/.ssh/):
- **Status**: Exists but empty
- **Expected**: Not needed for user repo operations
- **Impact**: None (root doesn't need GitHub access)

### 2. SOPS Secret Status

**Deploy keys directory** (/run/secrets/deploy-keys/):
- **Status**: Does not exist
- **Expected**: Should contain 3 deploy keys (nix-config, nix-secrets, chezmoi)
- **Impact**: Repository cloning impossible

**Individual deploy key secrets**:
- nix-config: **NOT FOUND**
- nix-secrets: **NOT FOUND**
- chezmoi: **NOT FOUND**

**User SSH key in SOPS**:
- **Status**: No SSH-related secrets found in /run/secrets/
- **Expected**: Personal SSH key should be deployed from shared.yaml
- **Impact**: Cannot authenticate to GitHub with personal account

**sops-nix.service**:
- **Status**: Unit could not be found
- **Expected**: Service should exist and be active
- **Impact**: **CRITICAL** - No secrets are being decrypted at all

**Diagnosis**: The SOPS secret deployment system is completely non-functional. This is the root cause of all other failures.

### 3. Systemd Service Status

**github-repos-init.service**:
- **Current Status**: inactive (dead) - condition not met
- **Condition**: ConditionPathExists=!/home/rain/nix-config/.git
- **Why inactive**: The repo was manually cloned, so condition is false
- **Previous failure**: Service failed on first boot with error "cannot run ssh: No such file or directory"

**Service logs analysis**:
```
Jan 02 22:54:46 griefling github-repos-init-start[904]: Cloning GitHub repos to /home/rain...
Jan 02 22:54:46 griefling github-repos-init-start[904]: Cloning nix-config...
Jan 02 22:54:46 griefling github-repos-init-start[921]: error: cannot run ssh: No such file or directory
Jan 02 22:54:46 griefling github-repos-init-start[921]: fatal: unable to fork
Jan 02 22:54:46 griefling systemd[1]: github-repos-init.service: Failed with result 'exit-code'.
```

**Root causes**:
1. `openssh` package not available in service PATH (despite being declared in module)
2. Even if SSH worked, no deploy keys exist (SOPS failure)
3. Even if deploy keys existed, no ~/.ssh/config exists to use them

### 4. Repository Status

**nix-config**:
- **Status**: Cloned and exists with .git directory
- **How**: Manually cloned (not via automation)
- **Ownership**: rain:users (correct)
- **Issue**: Relies on manual intervention, not automation

**nix-secrets**:
- **Status**: Cloned and exists with .git directory
- **How**: Manually cloned (not via automation)
- **Ownership**: rain:users (correct)
- **Note**: Nearly empty (just initialized), no actual content

**chezmoi**:
- **Status**: Directory exists but NOT cloned (.git missing)
- **Ownership**: rain:users
- **Issue**: Empty directory, dotfiles not deployed

**Conclusion**: All repos were manually intervened. Automation completely failed.

### 5. SSH Configuration

**SSH config file** (~/.ssh/config):
- **Status**: Does not exist
- **Expected**: Should contain GitHub host aliases for per-repo deploy keys
- **Impact**: Even if deploy keys existed, git wouldn't know to use them

**Expected SSH config content**:
```
Host github.com-nix-config
    HostName github.com
    User git
    IdentityFile ~/.ssh/nix-config-deploy
    StrictHostKeyChecking accept-new

Host github.com-nix-secrets
    HostName github.com
    User git
    IdentityFile ~/.ssh/nix-secrets-deploy
    StrictHostKeyChecking accept-new

Host github.com-chezmoi
    HostName github.com
    User git
    IdentityFile ~/.ssh/chezmoi-deploy
    StrictHostKeyChecking accept-new

Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new
```

**Issue**: programs.ssh.extraConfig in github-repos.nix should create this, but it's not being applied.

### 6. GitHub Authentication Test

All authentication tests **FAILED**:
- Personal SSH key: **Permission denied (publickey)**
- nix-config deploy key: **Permission denied (publickey)**
- nix-secrets deploy key: **Permission denied (publickey)**
- chezmoi deploy key: **Permission denied (publickey)**

**Expected**: At minimum, personal SSH key should work
**Actual**: No keys exist, all authentication fails

### 7. Module Configuration

**github-repos module enable check**:
- **Result**: Failed to eval
- **Error**: Attribute path incorrect or module not registered
- **Hint**: "Did you mean githubRepos?"
- **Action needed**: Check module registration and attribute naming

**SOPS defaultSopsFile check**:
- **Result**: Failed to eval
- **Error**: Cannot find Git revision in snowflake-secrets repository
- **Root cause**: Cannot access nix-secrets repo (no GitHub authentication)
- **Impact**: Cannot determine if SOPS is configured

**Disk layout check**:
- **Result**: btrfs (no impermanence)
- **Impact**: SSH keys should be in /etc/ssh/, not /persist/etc/ssh/
- **Note**: This is correct for griefling

## Specific Fixes Needed

### Fix 1: Diagnose SOPS Non-Functionality

**Priority**: CRITICAL (blocks everything else)

**Investigation needed**:
1. Check if sops-nix is imported in flake.nix
2. Check if griefling has hostSpec.hasSecrets = true
3. Check if griefling has sops.defaultSopsFile set
4. Check if griefling's age public key is registered in nix-secrets/.sops.yaml
5. Verify SSH host key exists at /etc/ssh/ssh_host_ed25519_key
6. Verify age key can be derived from SSH host key

**Files to check**:
- `/home/rain/nix-config/flake.nix` - sops-nix import
- `/home/rain/nix-config/hosts/griefling/default.nix` - host configuration
- `/home/rain/nix-secrets/.sops.yaml` - age key registration
- `/home/rain/nix-config/modules/common/sops.nix` - SOPS configuration

### Fix 2: Fix github-repos Module Enablement

**Priority**: HIGH (required for automation)

**Actions**:
1. Verify module is registered in module selection system
2. Check attribute naming (githubRepos vs github-repos)
3. Ensure module is enabled in griefling config or VM role
4. Fix conditional: change from `lib.mkIf (config.sops.defaultSopsFile or null != null)` to proper enable check

**Files to modify**:
- `/home/rain/nix-config/modules/services/development/github-repos.nix`
- `/home/rain/nix-config/hosts/griefling/default.nix` or `/home/rain/nix-config/roles/form-vm.nix`

### Fix 3: Add User Personal SSH Key Deployment

**Priority**: HIGH (enables GitHub authentication)

**Actions**:
1. Add user SSH key to SOPS secrets in github-repos.nix
2. Deploy from shared.yaml: "github-ssh-key" → ~/.ssh/id_ed25519
3. Set proper permissions: 600 for private key
4. Update SSH config to include personal key configuration

**Files to modify**:
- `/home/rain/nix-config/modules/services/development/github-repos.nix`

**New SOPS secret**:
```nix
"github-ssh-key" = {
  sopsFile = "${sopsFolder}/shared.yaml";
  owner = primaryUser;
  path = "${homeDir}/.ssh/id_ed25519";
  mode = "0600";
};
```

### Fix 4: Fix Service PATH and Dependencies

**Priority**: MEDIUM (service must run successfully)

**Actions**:
1. Ensure openssh is actually available in service environment
2. Add better dependency ordering: After=sops-nix.service
3. Add ConditionPathExists for SOPS secret paths
4. Add retry logic for git clone operations
5. Add better error logging

**Files to modify**:
- `/home/rain/nix-config/modules/services/development/github-repos.nix`

### Fix 5: Add Chezmoi Deployment Automation

**Priority**: MEDIUM (nice to have)

**Actions**:
1. Check if modules/apps/terminal/chezmoi.nix already handles deployment
2. If not, add chezmoi-init.service to github-repos.nix
3. Service should run after github-repos-init.service
4. Service should run chezmoi init && chezmoi apply
5. Add marker file to prevent re-runs

**Files to modify**:
- `/home/rain/nix-config/modules/services/development/github-repos.nix` or
- `/home/rain/nix-config/modules/apps/terminal/chezmoi.nix`

## Impact Assessment

**Current state**: Complete automation failure
- ❌ SSH keys not deployed
- ❌ SOPS secrets not decrypted
- ❌ Deploy keys unavailable
- ❌ User SSH key unavailable
- ❌ SSH config not created
- ❌ Service cannot run (missing ssh executable)
- ❌ Repository cloning failed
- ❌ Chezmoi deployment failed
- ❌ Manual intervention required for basic functionality

**Expected state after fixes**:
- ✅ SOPS secrets decrypt successfully
- ✅ Deploy keys deployed to ~/.ssh/
- ✅ User SSH key deployed to ~/.ssh/id_ed25519
- ✅ SSH config created with all host aliases
- ✅ github-repos-init.service runs successfully
- ✅ All three repos cloned automatically
- ✅ Chezmoi dotfiles deployed automatically
- ✅ Zero manual intervention required

## Recommended Fix Order

1. **Fix SOPS** (CRITICAL): Diagnose why sops-nix.service doesn't exist
2. **Fix module enablement** (HIGH): Ensure github-repos module is active
3. **Add user SSH key** (HIGH): Deploy personal SSH key from shared.yaml
4. **Fix service PATH** (MEDIUM): Ensure openssh available, add dependencies
5. **Add chezmoi deployment** (MEDIUM): Automate dotfiles deployment

## Files to Investigate/Modify

Priority order:
1. `/home/rain/nix-config/flake.nix` - Check sops-nix import
2. `/home/rain/nix-config/hosts/griefling/default.nix` - Check host SOPS config
3. `/home/rain/nix-secrets/.sops.yaml` - Check age key registration
4. `/home/rain/nix-config/modules/services/development/github-repos.nix` - Fix module
5. `/home/rain/nix-config/modules/common/sops.nix` - Verify SOPS configuration
6. `/home/rain/nix-config/roles/form-vm.nix` - Add default module enablement

## Next Steps

1. Read and analyze the files listed above
2. Implement fixes in priority order
3. Test each fix incrementally
4. Verify end-to-end functionality
5. Document any additional findings
