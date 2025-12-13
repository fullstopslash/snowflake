# Research: Architecture Reorganization

## Target Architecture

The user wants a clean three-tier architecture:

```
/modules  - Pure settings and definitions (mkOption/mkEnableOption only)
            No role logic, just atomic configurable units.

/hosts    - Super minimal host files (~15-30 lines)
            Just: hardware-configuration, disk layout, role selection, hostname
            No direct module configuration.

/roles    - Meta-modules that compose /modules
            Role = collection of module enables + role-specific defaults
            Examples: desktop, server, vm, laptop, development, mediacenter
```

## Current State Analysis

### /modules (Current)
```
modules/
├── apps/           # Some have enable options, some don't
│   ├── cli/        # shell.nix, tools.nix - have options
│   ├── development/# latex.nix - has option
│   ├── gaming/     # has option
│   └── media/      # NO enable option - unconditional
├── common/         # Universal settings (host-spec, sops, etc.)
├── disks/          # Declarative disk layouts
├── hardware/       # GPU, input
├── home/           # Home-manager modules
├── services/       # Services (many need enable options)
├── theming/        # stylix.nix - has option
└── users/          # User management
```

**Issues:**
- media/default.nix is unconditional
- plasma.nix is unconditional
- Many modules in scanPaths dirs lack enable options
- Some "role logic" mixed into modules

### /hosts (Current)
```
hosts/
├── griefling/     # 55 lines - pretty close to target
├── iso/           # Special case
├── malphas/       # 30 lines - good example
└── template/      # Reference for new hosts
```

**Issues:**
- griefling is close but could be slimmer
- malphas is good example of target pattern

### /roles (Current)
```
roles/
├── default.nix        # Role system entry point
├── common.nix         # Universal baseline
├── hw-darwin.nix
├── hw-desktop.nix     # PROBLEM: imports outside mkIf
├── hw-laptop.nix      # PROBLEM: imports outside mkIf
├── hw-pi.nix
├── hw-server.nix
├── hw-tablet.nix      # PROBLEM: imports outside mkIf
├── hw-vm.nix          # imports only display-manager (OK after fix)
├── task-development.nix
├── task-mediacenter.nix  # PROBLEM: imports outside mkIf
├── task-secret-management.nix
├── task-test.nix
└── task-vm-hardware.nix
```

**Issues:**
- Hardware roles (hw-*) have imports outside mkIf blocks
- Task roles (task-*) also have unconditional imports
- Roles should ONLY enable modules, not import them

## Target State

### /modules (Target)
Every module MUST have:
1. `options.myModules.CATEGORY.NAME.enable = lib.mkEnableOption "Description";`
2. `config = lib.mkIf cfg.enable { ... };`
3. No role-specific logic

### /hosts (Target)
Minimal pattern:
```nix
{ ... }: {
  imports = [ ./hardware-configuration.nix ];

  disks = { enable = true; layout = "btrfs"; device = "/dev/vda"; };

  hostSpec.hostName = "myhost";
  hostSpec.primaryUsername = "rain";

  roles.vm = true;       # Hardware role
  roles.test = true;     # Task role
}
```

### /roles (Target)
NO imports outside mkIf. Just enable options:
```nix
{ config, lib, ... }:
let cfg = config.roles; in {
  config = lib.mkIf cfg.desktop {
    myModules.desktop.plasma.enable = lib.mkDefault true;
    myModules.desktop.hyprland.enable = lib.mkDefault true;
    myModules.apps.gaming.enable = lib.mkDefault true;
    myModules.apps.media.enable = lib.mkDefault true;
    # ... etc
  };
}
```

## Migration Path

1. **Phase 10 (already planned)**: Fix unconditional imports, add enable options
2. **Phase 11**: Move module imports to roles/common.nix central location
3. **Phase 12**: Refactor hosts to minimal pattern
4. **Phase 13**: Document new architecture, create host template

## Questions for User

1. Should roles/common.nix import ALL modules (so they're always available to enable)?
   - Pro: Simplifies role files (just enable options)
   - Con: Slower evaluation for all hosts

2. Alternative: Keep module imports in individual roles but inside mkIf?
   - Pro: Only loads modules for enabled roles
   - Con: More complex role files

3. Should /home/ be renamed to /home-manager/ for clarity?
   - Already done in Phase 7 per roadmap

## Recommended Approach

**Central module import in roles/common.nix:**

```nix
# roles/common.nix
{
  imports = [
    # All module directories - makes options available
    (lib.custom.relativeToRoot "modules/services")
    (lib.custom.relativeToRoot "modules/apps")
    # etc.
  ];

  # Modules don't activate until enabled
}
```

This way:
- Roles just set `myModules.*.enable = true`
- No imports needed in individual role files
- Clean separation of concerns
