# Phase 2 Plan 3: Role Definitions Summary

**All 7 device roles created with conditional module imports and sensible defaults**

## Accomplishments

- Created role option system with mutual exclusivity assertion
- Implemented 7 device role definitions (desktop, laptop, server, pi, tablet, darwin, vm)
- Each role conditionally imports appropriate modules from the reorganized module library
- Established working pattern: unconditional imports, conditional config with lib.mkIf
- All roles set sensible defaults using lib.mkDefault (user-overridable)

## Files Created/Modified

### Role Infrastructure

**modules/common/roles.nix** (NEW)
- Defines `roles.*` enable options for all 7 device types
- Implements assertion ensuring only one role can be enabled at a time
- Auto-imported via modules/common/default.nix (lib.custom.scanPaths)

**roles/default.nix** (NEW)
- Imports all 7 role definition files
- Entry point for the role system

### Role Definitions (7 files)

**roles/desktop.nix** (NEW)
- Full GUI workstation role
- Imports: desktop, audio, cli, fonts, media, gaming, theming, development, networking, security, ai modules
- Defaults: xserver enabled, graphics enabled

**roles/laptop.nix** (NEW)
- Mobile workstation role with power management
- Imports: Same modules as desktop (duplicated to avoid inheritance complexity)
- Defaults: All desktop defaults + power management, bluetooth, libinput, wifi powersave

**roles/server.nix** (NEW)
- Headless server role
- Imports: cli, networking, security modules
- Defaults: openssh enabled, firewall enabled, no GUI, no sound

**roles/pi.nix** (NEW)
- Raspberry Pi role (aarch64, minimal)
- Imports: cli, networking modules
- Defaults: extlinux bootloader, minimal docs, openssh enabled

**roles/tablet.nix** (NEW)
- Touch-friendly role
- Imports: desktop, audio, cli, fonts, media modules
- Defaults: libinput enabled, power management enabled

**roles/darwin.nix** (NEW)
- macOS placeholder role
- No imports (requires nix-darwin integration)
- Emits warning that it's a placeholder

**roles/vm.nix** (NEW)
- Virtual machine testing role
- Imports: cli modules
- Defaults: qemu guest tools, spice agent, minimal docs, fast boot

## Architecture Decisions

### Import Pattern Fix (Critical Deviation)

**Problem:** The plan showed `imports = [...]` inside `config = lib.mkIf`, which doesn't work in Nix because imports are evaluated at module evaluation time, not config merge time.

**Solution:** Used the correct pattern:
```nix
{
  # Imports at top level - always evaluated
  imports = [ ../modules/... ];

  # Config wrapped in lib.mkIf - conditionally applied
  config = lib.mkIf cfg.rolename {
    # defaults here
  };
}
```

This means:
- All modules are imported regardless of role enablement
- Individual modules have their own enable options
- Role config sets sensible defaults with lib.mkDefault
- Users can override any default

### Laptop Role Design

**Initial approach (discarded):** Have laptop import desktop.nix and set `roles.desktop = true`

**Problem:** Would violate the "only one role" assertion

**Final approach:** Laptop duplicates desktop's imports and adds laptop-specific config
- Trade-off: Some duplication vs. cleaner semantics
- Benefit: Clear, independent roles without inheritance magic

## Verification Results

| Check | Result |
|-------|--------|
| roles/ directory exists | ✅ /home/rain/nix-config/roles/ |
| All 7 role files + default.nix | ✅ 8 files total |
| modules/common/roles.nix | ✅ Options defined |
| All files parse without errors | ✅ 8/8 files parse successfully |
| Role mutual exclusivity | ✅ Assertion in place |

## Module Import Matrix

| Role | Desktop | Audio | CLI | Fonts | Media | Gaming | Theming | Development | Networking | Security | AI | Storage |
|------|---------|-------|-----|-------|-------|--------|---------|-------------|------------|----------|----|----|
| desktop | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | - |
| laptop | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | - |
| server | - | - | ✅ | - | - | - | - | - | ✅ | ✅ | - | - |
| pi | - | - | ✅ | - | - | - | - | - | ✅ | - | - | - |
| tablet | ✅ | ✅ | ✅ | ✅ | ✅ | - | - | - | - | - | - | - |
| darwin | - | - | - | - | - | - | - | - | - | - | - | - |
| vm | - | - | ✅ | - | - | - | - | - | - | - | - | - |

## Usage Pattern

To use a role, hosts will:

1. Import the roles system:
   ```nix
   imports = [ ../../roles ];
   ```

2. Enable one role:
   ```nix
   roles.desktop = true;
   # or
   roles.laptop = true;
   ```

3. All appropriate modules are imported, with sensible defaults set

4. Override defaults as needed:
   ```nix
   services.xserver.enable = false;  # Override with higher priority
   ```

## Statistics

- **Roles created:** 7 (desktop, laptop, server, pi, tablet, darwin, vm)
- **Role infrastructure files:** 2 (roles.nix, roles/default.nix)
- **Total files created:** 9
- **Lines of code:** ~350 lines total
- **Module categories covered:** 12 categories

## Issues Encountered

**Import pattern incompatibility (auto-fixed):**
- Plan showed imports inside config = lib.mkIf
- This doesn't work in Nix (imports evaluated earlier than config)
- Fixed by moving imports to top level
- Documented in "Architecture Decisions" section

## Next Steps

Phase 2, Plan 4 will:
- Update host configurations to use the new role system
- Remove old role imports from ~/nix/roles/
- Test that hosts build successfully with new roles
- Document the role system in README

## Notes

- All roles use lib.mkDefault for defaults (lowest priority, easily overridden)
- Darwin role is a placeholder - requires nix-darwin integration work
- Role system is complete and ready for host integration
- 39 modules from previous plans are now consumable via roles
- The import pattern ensures modules are always available, but only configured when role is enabled
