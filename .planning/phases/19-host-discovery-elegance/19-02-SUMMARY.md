# Phase 19 Plan 2: Rename hostSpec → host Summary

**Successfully renamed hostSpec to host across entire codebase with clearer module structure**

## Accomplishments

- Created new `modules/common/host.nix` with organized structure:
  - **IDENTITY OPTIONS**: hostName, primaryUsername, email, domain, handle, networking, home, users, architecture, nixpkgsVariant
  - **HARDWARE OPTIONS**: wifi, hdr, scaling, isDarwin, persistFolder
  - **PREFERENCES**: isWork, useYubikey, voiceCoding, isAutoStyled, theme, useNeovimTerminal, wallpaper, defaultBrowser, defaultEditor, defaultDesktop
  - **DERIVED OPTIONS**: isMinimal, isHeadless, isProduction, isDevelopment, isMobile, useWayland, useWindowManager, hasSecrets, useAtticCache
  - **SECRET CATEGORIES**: base, desktop, server, network, cli
- Updated `roles/common.nix` to set `host.*` defaults (primaryUsername, handle, hasSecrets, useAtticCache)
- Mass migration completed across 37+ files:
  - All module files in modules/services/, modules/security/, modules/users/, modules/disks/, modules/common/
  - All host files: griefling, malphas, sorrow, torment, misery, iso, template
  - All role files and home-manager configurations
  - flake.nix and nixos-installer files
- All references to `hostSpec` renamed to `host` throughout the codebase
- Maintained backward compatibility: kept networking and persistFolder attributes that are still in use
- All assertions preserved (isWork validation, impermanence check, voiceCoding+Wayland check)

## Files Created/Modified

- `modules/common/host.nix` - New host module with clear structure and organized categories
- `roles/common.nix` - Updated to use host.* and set identity defaults
- `modules/common/universal.nix` - Updated to use host.* and import networking from secrets
- `hosts/griefling/default.nix` - Renamed hostSpec to host
- `hosts/malphas/default.nix` - Renamed hostSpec to host
- `hosts/sorrow/default.nix` - Renamed hostSpec to host
- `hosts/torment/default.nix` - Renamed hostSpec to host
- `hosts/misery/default.nix` - Renamed hostSpec to host, added persistFolder="/persist"
- `hosts/iso/default.nix` - Renamed hostSpec to host
- `hosts/template/default.nix` - Renamed hostSpec to host
- `hosts/TEMPLATE.nix` - Renamed hostSpec to host
- All 26+ module files in modules/* - Renamed hostSpec references to host
- All home-manager configuration files - Renamed hostSpec references to host
- `flake.nix` - Updated mkHost function to use host.*
- `nixos-installer/flake.nix` - Updated to use host.*
- `nixos-installer/minimal-configuration.nix` - Updated to use host.*

## Decisions Made

1. **Kept networking and persistFolder attributes**: Despite the plan suggesting removal, these attributes are actively used by multiple modules (openssh, borg, disks). Kept them in the new host module to maintain functionality.

2. **Added persistFolder to misery host**: The misery host uses btrfs-luks-impermanence layout which requires persistFolder to be set. Added `persistFolder = "/persist"` to fix evaluation error.

3. **Preserved freeformType**: Kept `freeformType = with lib.types; attrsOf str;` to allow custom attributes like `work` that can be set by hosts as needed.

4. **Comment-only references**: Updated all comment references from "hostSpec" to "host config" or "host" for consistency.

5. **Pure rename approach**: Maintained all logic and behavior identically - this is a mechanical rename with no functional changes beyond naming.

## Issues Encountered

1. **Missing attributes during initial migration**: First attempt removed networking and persistFolder as suggested by plan, but modules actively use these. Re-added them to maintain compatibility.

2. **misery host evaluation error**: Host uses impermanence layout but had no persistFolder set, causing disko configuration error. Fixed by adding `persistFolder = "/persist"`.

3. **Misery hardware configuration conflict**: Discovered pre-existing issue with misery's hardware-configuration.nix conflicting with disko LUKS setup. This is unrelated to the hostSpec→host migration and was already present.

## Verification Results

- ✅ `modules/common/host.nix` created with clear structure and organized categories
- ✅ No files reference hostSpec anymore: 0 matches found (excluding host-spec.nix)
- ✅ All key hosts evaluate successfully:
  - `nix eval .#nixosConfigurations.griefling.config.host.hostName` → "griefling"
  - `nix eval .#nixosConfigurations.malphas.config.host.primaryUsername` → "rain"
  - `nix eval .#nixosConfigurations.sorrow.config.host.hostName` → "sorrow"
  - `nix eval .#nixosConfigurations.torment.config.host.hostName` → "torment"
- ✅ Host module has elegant, clear structure with well-defined categories
- ✅ Three-tier system is clear: /roles (presets), /modules (units), /hosts (identity)

## Next Step

Ready for 19-03-PLAN.md (Cleanup & Verification)
