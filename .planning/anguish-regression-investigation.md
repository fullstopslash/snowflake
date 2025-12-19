# Investigation Plan: Anguish TPM and Login Regressions

## Problem Statement

After removing duplicate SOPS secret definitions from `hosts/anguish/default.nix`, two critical regressions appeared:

1. **TPM auto-unlock broken**: System prompts for disk password at every boot (TPM Clevis unlock failing)
2. **User login broken**: User "rain" cannot login after rebuild
3. **Atuin autologin not working**: (Pre-existing issue)

## Current State

- VM is running but connections are unstable (resetting/timing out)
- Both SSH ports (2222, 22222) are listening but connections fail
- System appears stuck or in boot loop

## Investigation Steps

### Phase 1: Identify Root Cause of TPM Regression

**1.1 Check if TPM token exists and is valid**
- Location: `/persist/etc/clevis/bcachefs-root.jwe`
- Verify token wasn't deleted or corrupted
- Check token permissions

**1.2 Review bcachefs-unlock.nix changes**
- Compare current version with working version
- Check if removal of SOPS definitions affected token paths
- Verify initrd.clevis.devices configuration

**1.3 Check filesystem device paths**
- Verify `rootDevice` and `persistDevice` values
- Ensure they match what bcachefs module expects
- Check if device paths changed between builds

**1.4 Review build warnings**
- Check if "TPM unlock is enabled but token not found" warning appeared
- Verify Clevis packages are in initrd
- Check if clevis module is properly enabled

### Phase 2: Identify Root Cause of Login Regression

**2.1 Check SOPS secret decryption**
- Verify `/run/secrets-for-users/passwords/rain` exists
- Check if secret file has content
- Verify permissions (should be readable by activation scripts)

**2.2 Review users module behavior**
- Check if `modules/users/default.nix` lines 89-99 are working correctly
- Verify `hasSecrets = true` and `!isMinimal` conditions met
- Check if users are in `config.host.users` array

**2.3 Check for conflicts**
- Verify no duplicate user definitions
- Check if `mutableUsers = false` is still set
- Verify `hashedPasswordFile` is being set correctly

**2.4 Compare with working host**
- Compare anguish config with malphas/griefling
- Identify any missing configuration

### Phase 3: Check for Unintended Side Effects

**3.1 Review all commits since last working state**
- Last known working: before removing SOPS definitions
- Changes made: removed `sops.secrets."passwords/rain"` block
- Check if any other files were modified

**3.2 Verify flake.lock state**
- Check if nix-secrets input changed
- Verify no unexpected dependency updates

**3.3 Check host.users configuration**
- Verify "rain" is in the users list
- Check if users list is populated correctly

### Phase 4: Fix Strategy

**4.1 If TPM token missing/invalid:**
- Regenerate token: `sudo just bcachefs-setup-tpm anguish`
- Verify token deployed to correct location
- Rebuild and test

**4.2 If SOPS not decrypting:**
- Check age key authorization in .sops.yaml
- Verify shared.yaml has correct structure
- Re-verify key fingerprints match

**4.3 If users module not creating secrets:**
- May need explicit secret definitions per-host
- Or fix host.users population logic

**4.4 If device paths mismatched:**
- Update clevis.devices to use correct paths
- Ensure rootDevice variable matches filesystem device

## Comparison Checklist

Compare anguish with working hosts (malphas, griefling):

- [ ] `host.hasSecrets` setting
- [ ] `host.users` array contents
- [ ] SOPS secret definitions (explicit vs auto-generated)
- [ ] Disk layout and encryption method
- [ ] TPM configuration presence
- [ ] Age key in .sops.yaml

## Verification Criteria

System is fixed when:
- [ ] TPM auto-unlock works (no password prompt at boot)
- [ ] User "rain" can login with SOPS-managed password
- [ ] SOPS secrets decrypt to `/run/secrets-for-users/passwords/rain`
- [ ] No build warnings about missing tokens or keys
- [ ] System boots without manual intervention

## Rollback Option

If investigation takes too long:
1. Revert commit: `jj undo`
2. Restore duplicate SOPS definitions
3. Identify minimal working change
4. Apply proper fix incrementally
