# Meta-Prompt: Centralize stateVersion Configuration

## Context

You are working on a NixOS flake-based configuration repository that manages multiple hosts. The repository follows a three-tier architecture:

- **Modules** (`/modules`): Reusable configuration building blocks
- **Roles** (`/roles`): Task and form-factor based configurations
- **Hosts** (`/hosts`): Minimal per-host declarations

## Problem Statement

The `system.stateVersion` and `home.stateVersion` settings are currently scattered across the repository in multiple locations:

### Current State

1. **flake.nix:77** - Sets `system.stateVersion = "25.05"` as a module for all NixOS hosts
2. **hosts/iso/default.nix:177** - Overrides with `system.stateVersion = "25.05"` (redundant)
3. **modules/users/default.nix:141** - Sets `home.stateVersion = "23.05"` for all users
4. **modules/users/default.nix:150** - Sets `home.stateVersion = "23.05"` for root user
5. **Various planning docs** - Reference inconsistent versions (23.05, 24.05, 25.05)

### Issues

1. **Inconsistency**: `system.stateVersion` is "25.05" but `home.stateVersion` is "23.05"
2. **Duplication**: ISO host unnecessarily repeats the flake.nix setting
3. **No clear override path**: Unclear how hosts/roles should override if needed
4. **Messy**: Multiple locations make it hard to audit and maintain
5. **No documentation**: No clear guidance on when to update stateVersion

## Goal

Design and implement a clean, centralized stateVersion management system where:

1. ✅ **Single source of truth** - One primary location for both system and home stateVersion
2. ✅ **Clear override hierarchy** - Obvious, documented path for roles/hosts to override if needed
3. ✅ **Consistency** - Both system and home use appropriate versions
4. ✅ **Maintainability** - Easy to update when migrating to new NixOS releases
5. ✅ **Documentation** - Clear comments explaining purpose and upgrade path

## Requirements

### Functional Requirements

1. **Default stateVersion**: Set centrally with clear ownership
2. **Override capability**: Roles and hosts can override with `lib.mkForce` if absolutely necessary
3. **Consistency check**: System and home stateVersion should be compatible
4. **ISO exception**: ISO installer may need different handling
5. **Per-user flexibility**: Allow different home.stateVersion per user if needed

### Non-Functional Requirements

1. **Minimal changes**: Don't break existing hosts
2. **Clear documentation**: Comments explain what stateVersion is and when to change it
3. **Follows architecture**: Solution fits the three-tier module/role/host pattern
4. **Auditable**: Easy to grep and find all stateVersion settings

## Design Constraints

### What stateVersion Controls

From NixOS documentation:
- `system.stateVersion` determines the default settings for stateful services
- Should NOT be changed on existing systems (causes incompatibilities)
- Only set during initial installation
- New hosts should use the current NixOS release version

### Current Architecture Patterns

The repository uses:
- `flake.nix` for system-wide settings and module composition
- `modules/common/` for configuration shared across all hosts
- `lib.mkDefault` in roles for overridable defaults
- `lib.mkForce` in hosts for mandatory overrides

## Task Breakdown

### Phase 1: Research & Analysis

**Objective**: Understand current state and design optimal solution

**Tasks**:
1. Audit all occurrences of `system.stateVersion` and `home.stateVersion`
2. Document which hosts/users currently exist and their versions
3. Research NixOS best practices for stateVersion management in flakes
4. Identify the appropriate "source of truth" location (flake.nix vs modules/common/)
5. Design override hierarchy (how roles/hosts can override if needed)

**Deliverables**:
- Complete audit of current stateVersion settings
- Design document with proposed architecture
- Justification for chosen approach

### Phase 2: Design Solution

**Objective**: Create clean, maintainable stateVersion management

**Design Considerations**:

1. **Where to centralize?**
   - Option A: Keep in `flake.nix` (system-wide, visible)
   - Option B: Move to `modules/common/default.nix` (with other common settings)
   - Option C: Create dedicated `modules/common/state-version.nix`

2. **How to handle home.stateVersion?**
   - Option A: Keep in `modules/users/default.nix` (current)
   - Option B: Move to same location as system.stateVersion
   - Option C: Make it configurable via host options

3. **Override mechanism?**
   - Use `lib.mkDefault` for central setting (allows easy override)
   - Document when overrides are legitimate
   - Provide example for hosts that need different versions

4. **Version consistency?**
   - Should home.stateVersion match system.stateVersion?
   - Handle legacy systems with older stateVersions
   - Migration path for updates

**Tasks**:
1. Choose primary location for stateVersion (with justification)
2. Design module option structure (if needed)
3. Define override hierarchy and priorities
4. Create migration plan for existing hosts
5. Write documentation comments

**Deliverables**:
- Architectural decision document
- Proposed module structure
- Override examples
- Migration checklist

### Phase 3: Implementation

**Objective**: Implement the centralized stateVersion system

**Tasks**:

#### Task 1: Create centralized stateVersion module (if new location chosen)

**File**: TBD based on design (e.g., `modules/common/state-version.nix`)

**Actions**:
```nix
# Example structure (adapt based on design):
{
  config,
  lib,
  ...
}: {
  options.stateVersions = {
    system = lib.mkOption {
      type = lib.types.str;
      default = "25.05";
      description = ''
        NixOS state version - determines default settings for stateful services.

        DO NOT CHANGE on existing systems.
        Only set during initial installation to match the NixOS release version.

        Override in host config only if system was installed with older release:
          stateVersions.system = lib.mkForce "24.05";
      '';
    };

    home = lib.mkOption {
      type = lib.types.str;
      default = "25.05";
      description = ''
        Home Manager state version - determines default home-manager settings.

        DO NOT CHANGE on existing user environments.
        Should generally match system.stateVersion.
      '';
    };
  };

  config = {
    # Apply to NixOS
    system.stateVersion = lib.mkDefault config.stateVersions.system;

    # Note: home.stateVersion applied via modules/users/default.nix
  };
}
```

**Verification**:
- Module loads without errors
- Default values propagate correctly

#### Task 2: Update home.stateVersion in modules/users/default.nix

**File**: `modules/users/default.nix`

**Actions**:
- Replace hardcoded `"23.05"` with reference to central config
- Update both user and root stateVersion settings
- Add comment explaining the setting

**Example**:
```nix
# Before:
home.stateVersion = "23.05"; # Required by home-manager

# After:
home.stateVersion = config.stateVersions.home;  # From centralized config
```

**Verification**:
- Users still get stateVersion set correctly
- No evaluation errors

#### Task 3: Clean up redundant settings

**Files to update**:
- `hosts/iso/default.nix` - Remove redundant `system.stateVersion = "25.05"`
- Add comment indicating it inherits from central config

**Verification**:
- ISO still builds correctly
- stateVersion still set to "25.05"

#### Task 4: Update flake.nix (if design changes location)

**File**: `flake.nix`

**Actions** (depends on design decision):
- If keeping in flake.nix: Add comments and improve clarity
- If moving to module: Remove from flake.nix, import new module
- Ensure central config loads before host configs

**Verification**:
- All hosts still build
- stateVersion applied correctly

#### Task 5: Document override pattern

**File**: Create `docs/state-version.md` or add to existing docs

**Content**:
```markdown
# StateVersion Management

## Overview

The `system.stateVersion` and `home.stateVersion` are managed centrally in [location].

## Default Versions

- System: `25.05` (current NixOS release)
- Home Manager: `25.05` (matches system)

## When to Override

⚠️ **WARNING**: Do NOT change stateVersion on existing systems!

Override ONLY if:
1. System was originally installed with older NixOS release
2. Migrating from another configuration

## How to Override

In your host config (`hosts/[hostname]/default.nix`):

```nix
# Example: System installed with NixOS 24.05
stateVersions.system = lib.mkForce "24.05";
stateVersions.home = lib.mkForce "24.05";
```

## Updating for New Releases

When a new NixOS release comes out:

1. Update default in [central location]
2. New hosts automatically use new version
3. Existing hosts keep their original version
```

**Verification**:
- Documentation is clear and accurate
- Examples work correctly

#### Task 6: Add verification helper (optional)

**File**: `modules/common/warnings.nix` or new file

**Purpose**: Warn if stateVersion seems inconsistent

**Example**:
```nix
{
  config,
  lib,
  ...
}: {
  config.warnings = lib.optional
    (config.stateVersions.system != config.stateVersions.home)
    ''
      Warning: system.stateVersion (${config.stateVersions.system})
      doesn't match home.stateVersion (${config.stateVersions.home}).

      This is usually fine for legacy systems, but verify it's intentional.
    '';
}
```

**Verification**:
- Warning appears when versions mismatch
- Warning is helpful, not alarming

### Phase 4: Testing & Verification

**Objective**: Ensure changes work across all hosts

**Tasks**:

1. **Build all hosts**:
   ```bash
   nix flake check
   for host in sorrow torment griefling misery malphas; do
     nix build .#nixosConfigurations.$host.config.system.build.toplevel --dry-run
   done
   ```

2. **Verify stateVersion values**:
   ```bash
   # Check system.stateVersion
   for host in sorrow torment griefling misery malphas; do
     echo "$host: $(nix eval .#nixosConfigurations.$host.config.system.stateVersion)"
   done

   # Check home.stateVersion
   nix eval .#nixosConfigurations.sorrow.config.home-manager.users.rain.home.stateVersion
   ```

3. **Test override mechanism**:
   - Temporarily add override to a test host
   - Verify override takes precedence
   - Remove test override

4. **Review all changes**:
   - No unintended stateVersion changes
   - Documentation is accurate
   - Comments are helpful

**Success Criteria**:
- ✅ All hosts build successfully
- ✅ stateVersion values are correct and consistent
- ✅ No new evaluation warnings
- ✅ Override mechanism works as documented
- ✅ Changes follow architectural patterns

### Phase 5: Documentation & Cleanup

**Objective**: Document the new system and clean up old references

**Tasks**:

1. **Update planning docs**:
   - Add entry to `.planning/` documenting this refactor
   - Create `SUMMARY.md` with before/after comparison

2. **Update host templates**:
   - `hosts/TEMPLATE.nix` - Add comment about stateVersion inheritance
   - `hosts/template/default.nix` - Update comment

3. **Add to migration guide** (if exists):
   - Document stateVersion management for new contributors
   - Explain when and how to override

4. **Audit and fix outdated references**:
   - Grep for old comments mentioning stateVersion
   - Update to reference new central location

**Deliverables**:
- Updated documentation
- Clean, consistent comments
- Clear guidance for future maintainers

## Success Criteria

### Functional Goals

- ✅ Single source of truth for default stateVersions
- ✅ Clear, documented override path
- ✅ All hosts build successfully with correct versions
- ✅ No duplicate or conflicting settings

### Quality Goals

- ✅ Clean, maintainable code
- ✅ Follows repository architectural patterns
- ✅ Well-documented with helpful comments
- ✅ Easy to audit (`grep stateVersion` shows clear structure)

### Operational Goals

- ✅ No breaking changes to existing hosts
- ✅ Easy to update for new NixOS releases
- ✅ New contributors understand the system

## Deliverables

1. **Updated configuration files** with centralized stateVersion
2. **Documentation** explaining the system
3. **Migration summary** documenting changes made
4. **Verification results** showing all hosts work correctly

## Notes

### Important Context

- The repository recently completed architectural cleanup (Phase 21-01)
- Follows strict separation: modules → roles → hosts
- Uses `lib.mkDefault` for overridable role settings
- Prefers centralization over duplication

### Best Practices

1. Use `lib.mkDefault` for central settings (allows override)
2. Use `lib.mkForce` only when override is necessary
3. Document why overrides exist
4. Keep host files minimal and clear

### Related Work

- Phase 21-01: Architecture elegance refactor (just completed)
- Established patterns for centralizing config in roles
- Similar approach should work for stateVersion

## Execution Instructions

1. **Start with Phase 1**: Audit and design
2. **Get approval**: Present design before implementing
3. **Implement incrementally**: One phase at a time
4. **Test frequently**: Build after each change
5. **Document thoroughly**: Future maintainers will thank you

Good luck! The goal is a clean, obvious, maintainable system for managing stateVersion across the entire repository.
