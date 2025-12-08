# Phase 2 Plan 1: Module Directory Structure and Migration Summary

**Module organization established; 17 core and desktop modules migrated from ~/nix/roles/**

## Accomplishments

- Created organized module directory structure (apps/, services/, hardware/)
- Migrated 17 modules from ~/nix/roles/ to new structured locations
- Preserved all file contents and functionality (relocation only)
- Created default.nix files for easy module importing using lib.custom.scanPaths

## Files Created/Modified

### Directory Structure Created

```
modules/
├── apps/
│   ├── browsers/      (placeholder)
│   ├── cli/           (tools.nix, shell.nix, atuin.nix, default.nix)
│   ├── editors/       (placeholder)
│   ├── fonts/         (default.nix)
│   ├── gaming/        (default.nix, moondeck.nix)
│   ├── media/         (default.nix, obs.nix)
│   ├── productivity/  (placeholder)
│   └── theming/       (stylix.nix, default.nix)
├── services/
│   ├── audio/         (tuning.nix, default.nix)
│   ├── desktop/       (common.nix, hyprland.nix, plasma.nix, niri.nix, greetd.nix, waybar.nix, default.nix)
│   ├── development/   (placeholder)
│   ├── networking/    (default.nix, tailscale.nix, syncthing.nix, vpn.nix)
│   └── storage/       (network-storage.nix, default.nix)
├── hardware/
│   ├── gpu/           (placeholder)
│   └── input/         (placeholder)
├── common/            (existing - kept intact)
├── home/              (existing - kept intact)
└── hosts/             (existing - kept intact)
```

### Modules Migrated (17 total)

**CLI/Shell (3 modules)**
- cli-tools.nix → modules/apps/cli/tools.nix
- shell.nix → modules/apps/cli/shell.nix
- atuin.nix → modules/apps/cli/atuin.nix

**Fonts (1 module)**
- fonts.nix → modules/apps/fonts/default.nix

**Networking (4 modules)**
- networking.nix → modules/services/networking/default.nix
- tailscale.nix → modules/services/networking/tailscale.nix
- syncthing.nix → modules/services/networking/syncthing.nix
- vpn.nix → modules/services/networking/vpn.nix

**Storage (1 module)**
- network-storage.nix → modules/services/storage/network-storage.nix

**Desktop Environment (6 modules)**
- desktop.nix → modules/services/desktop/common.nix
- hyprland.nix → modules/services/desktop/hyprland.nix
- plasma.nix → modules/services/desktop/plasma.nix
- niri.nix → modules/services/desktop/niri.nix
- greetd.nix → modules/services/desktop/greetd.nix
- waybar.nix → modules/services/desktop/waybar.nix

**Audio (1 module)**
- audio-tuning.nix → modules/services/audio/tuning.nix

**Media Apps (2 modules)**
- media.nix → modules/apps/media/default.nix
- obs.nix → modules/apps/media/obs.nix

**Gaming (2 modules)**
- gaming.nix → modules/apps/gaming/default.nix
- moondeck-buddy.nix → modules/apps/gaming/moondeck.nix

**Theming (1 module)**
- stylix.nix → modules/apps/theming/stylix.nix

### Default.nix Files Created

Created 7 default.nix files for auto-importing modules:
- /modules/apps/cli/default.nix
- /modules/services/networking/default.nix (replaced migrated networking.nix)
- /modules/services/storage/default.nix
- /modules/services/desktop/default.nix
- /modules/services/audio/default.nix
- /modules/apps/media/default.nix (renamed migrated media.nix)
- /modules/apps/gaming/default.nix (renamed migrated gaming.nix)
- /modules/apps/theming/default.nix

All use the pattern:
```nix
{ lib, ... }:
{
  imports = lib.custom.scanPaths ./.;
}
```

## Verification Results

| Check | Result |
|-------|--------|
| apps/ subdirectories | ✅ cli, fonts, media, gaming, theming created |
| services/ subdirectories | ✅ networking, desktop, audio, storage created |
| Core modules migrated | ✅ CLI, fonts, networking, storage in new locations |
| Desktop modules migrated | ✅ Desktop, audio, media, gaming, theming in new locations |
| Syntax validation | ✅ Sample modules parse without errors |
| Module count | ✅ 17 modules migrated |

## Decisions Made

1. **Used lib.custom.scanPaths for auto-imports** - Leveraged existing helper from Phase 1 for clean default.nix files
2. **Preserved file contents exactly** - No functional changes, only relocation (as specified in plan)
3. **Created placeholder directories** - Added browsers/, editors/, productivity/, gpu/, input/ with empty default.nix for future expansion

## Issues Encountered

None - migration completed without issues.

## Next Steps

Phase 2, Plan 2 will:
- Create role definitions that import these modules
- Wire up role system to host configurations
- Establish role inheritance patterns

## Notes

- Source ~/nix/roles/ directory still intact (not deleted)
- Modules maintain any input dependencies (stylix, sops-nix) - these will be wired when roles import them
- Hardware modules placeholder created but not populated (no hardware-specific modules in ~/nix/roles/)
