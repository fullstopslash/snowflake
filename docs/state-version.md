# StateVersion Management

## Overview

The `system.stateVersion` and `home.stateVersion` settings are managed centrally in `modules/common/state-version.nix`.

These settings determine compatibility defaults for stateful services and **should never be changed on existing systems**.

## Current Versions

- **System**: `25.11` (NixOS 25.11 release)
- **Home Manager**: `25.11` (matches system)

**Location**: `flake.nix` (lines 76-100)
**Reference**: `modules/common/state-version.nix` (documentation only)

## What is stateVersion?

From the NixOS manual:

> The `system.stateVersion` option sets the NixOS release version at the time of system installation. It controls default settings for stateful data and services to maintain compatibility across upgrades.

**Important**: This is **NOT** the NixOS version you're running. It's the version at which the system was **first installed**.

### Why It Matters

- Changing `stateVersion` on an existing system can break stateful services
- It affects default database schemas, file formats, and service configurations
- Once set during installation, it should remain unchanged for the system's lifetime

## How It Works

### Centralized Configuration

All hosts automatically inherit stateVersion from the module defined in flake.nix:

```nix
# flake.nix (lines 76-100)
modules = [
  # StateVersion must load first (needed by modules/users via roles/common)
  (
    { config, lib, ... }:
    {
      options.stateVersions = {
        system = lib.mkOption {
          default = "25.11";
          # ...
        };

        home = lib.mkOption {
          default = "25.11";
          # ...
        };
      };

      config = {
        system.stateVersion = lib.mkDefault config.stateVersions.system;
        # Warning for version mismatch
      };
    }
  )
  # ... other modules
];
```

### Automatic Application

- **NixOS**: Applied via `system.stateVersion = lib.mkDefault config.stateVersions.system`
- **Home Manager**: Applied in `modules/users/default.nix` for all users

## When to Override

⚠️ **WARNING**: Do NOT change stateVersion on existing systems!

Override ONLY if:

1. **Legacy system**: Installed with an older NixOS release
2. **Migration**: Moving configuration from another system
3. **Compatibility**: Specific service requires older defaults

## How to Override

### Best Practice: Explicit Declaration for Physical Hosts

**Recommended**: Always explicitly set stateVersion in physical/production host configs to document installation version:

```nix
# hosts/hostname/default.nix
{
  # ... other config ...

  # ========================================
  # STATE VERSION (explicit for physical hosts)
  # ========================================
  # This host will be deployed with NixOS 25.11
  # This setting must NEVER change after deployment
  stateVersions.system = lib.mkForce "25.11";
  stateVersions.home = lib.mkForce "25.11";
}
```

**Why explicit is better:**
- ✅ Clear documentation of installation version
- ✅ Survives changes to flake.nix defaults
- ✅ Prevents accidental version changes
- ✅ Makes host config self-documenting

### For Test VMs

Test VMs can inherit from flake.nix (no override needed):
- sorrow, torment, griefling, misery: use central default (25.11)
- Rebuilt frequently, so version changes are safe

### Legacy Systems

If migrating an existing system installed with older NixOS:

```nix
# hosts/legacy-host/default.nix
{
  # System originally installed with NixOS 24.05
  stateVersions.system = lib.mkForce "24.05";
  stateVersions.home = lib.mkForce "24.05";
}
```

### In Role Configuration

Roles should **not** override stateVersion (host-specific setting).

## Consistency Warning

The module will warn if `system.stateVersion` and `home.stateVersion` differ:

```
StateVersion mismatch detected:
  system.stateVersion = 25.11
  home.stateVersion   = 24.05

This is usually fine for legacy systems, but verify it's intentional.
```

This is informational - mismatched versions are OK if intentional (e.g., system upgraded but user environment kept at older version).

## Updating for New Releases

When a new NixOS release comes out (e.g., 25.17):

### For New Hosts

1. Update defaults in `flake.nix` (around lines 83 and 88):
   ```nix
   options.stateVersions = {
     system = lib.mkOption {
       default = "25.17";  # ← Update here
       # ...
     };
     home = lib.mkOption {
       default = "25.17";  # ← And here
       # ...
     };
   };
   ```

2. Update documentation in `modules/common/state-version.nix` (line 17)
3. New hosts automatically use new version
4. Commit with clear message: "chore: update stateVersion default to 25.17"

### For Existing Hosts

**DO NOTHING**. Existing hosts keep their original stateVersion - this is correct!

## Examples

### Example 1: New Host (Installed with NixOS 25.11)

```nix
# hosts/newhost/default.nix
{
  imports = [ ./hardware-configuration.nix ];

  roles = [ "desktop" ];

  host = {
    hostName = "newhost";
    primaryUsername = "user";
  };

  # No stateVersion override - inherits 25.11 from central config ✓
}
```

### Example 2: Legacy Host (Installed with NixOS 24.05)

```nix
# hosts/oldhost/default.nix
{
  imports = [ ./hardware-configuration.nix ];

  roles = [ "server" ];

  host = {
    hostName = "oldhost";
    primaryUsername = "admin";
  };

  # Override for legacy system
  stateVersions.system = lib.mkForce "24.05";
  stateVersions.home = lib.mkForce "24.05";
}
```

### Example 3: ISO Installer

```nix
# hosts/iso/default.nix
{
  # ... ISO config ...

  # Inherits latest stateVersion (25.11) for new installations
  # No override needed - comment indicates inheritance
}
```

## Architecture

### File Locations

```
flake.nix                         ← Central definition (lines 76-100)
modules/common/state-version.nix  ← Documentation reference only
modules/users/default.nix         ← Applies home.stateVersion
hosts/*/default.nix               ← Can override if needed
```

### Module Options

The `state-version.nix` module provides:

- `stateVersions.system` - NixOS state version
- `stateVersions.home` - Home Manager state version
- Automatic warning for version mismatches
- Uses `lib.mkDefault` for easy overrides

## Troubleshooting

### Warning: StateVersion Mismatch

**Symptom**: Build warning about system/home version mismatch

**Cause**: Different values for system and home stateVersion

**Solution**: Usually safe to ignore for legacy systems. If unintentional, update override to match.

### Service Compatibility Issues

**Symptom**: Service fails after NixOS upgrade

**Cause**: Service expects settings from newer stateVersion

**Solution**: Check service documentation. Some services may need manual migration if stateVersion is very old (e.g., 5+ years).

### Forgot Original Version

**Symptom**: Don't know which version system was installed with

**Solution**:
1. Check `system.stateVersion` in current config
2. If changing systems, be conservative (use older version)
3. When in doubt, use the current NixOS stable release

## FAQ

### Q: Should I update stateVersion when upgrading NixOS?

**A**: No! Keep the original version. It represents when the system was first installed, not which version you're running.

### Q: Can I have different stateVersions per host?

**A**: Yes, override in each host's `default.nix` as needed.

### Q: What if I change it by mistake?

**A**: Revert immediately via git. Changing stateVersion can break stateful services and may require manual data migration.

### Q: Does stateVersion affect which packages I get?

**A**: No, it only affects *default settings* for services. You always get the latest packages from your chosen nixpkgs input.

## References

- [NixOS Manual - Options - system.stateVersion](https://search.nixos.org/options?query=system.stateVersion)
- [Home Manager - Options - home.stateVersion](https://nix-community.github.io/home-manager/options.xhtml#opt-home.stateVersion)
- [NixOS Wiki - State Version](https://wiki.nixos.org/wiki/FAQ#I_upgraded_NixOS_but_my_system_changed_significantly.2C_what_happened.3F)
