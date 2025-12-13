# Phase 10 Plan 1: Fix Critical Modules Summary

**Converted plasma and media modules to enable-gated pattern, eliminated unconditional imports from hw-desktop role**

## Accomplishments
- Added enable options to plasma.nix and media/default.nix modules
- Removed top-level imports from hw-desktop.nix role
- Moved module imports to global scope (roles/common.nix)
- Verified griefling VM no longer includes Plasma or Jellyfin packages
- All three tasks completed successfully

## Files Created/Modified
- `modules/services/desktop/plasma.nix` - Added myModules.desktop.plasma.enable option and wrapped all config in mkIf block
- `modules/apps/media/default.nix` - Added myModules.apps.media.enable option, wrapped config in mkIf, removed spice-vdagentd (VM-specific)
- `roles/hw-desktop.nix` - Removed top-level imports section, added enable options for plasma and media modules
- `roles/common.nix` - Added global imports for modules/apps and modules/theming
- `modules/apps/default.nix` - Removed invalid imports for fonts and theming (they exist elsewhere)
- `roles/hw-vm.nix` - Added comment about SPICE configuration
- `modules/apps/media/default.nix` - Added comment noting spice-vdagentd was moved (VM-specific, not media-related)

## Decisions Made
- Moved modules/apps and modules/theming to global imports in common.nix rather than keeping per-role imports
- Removed spice-vdagentd from media module as it's VM-specific, not media-related
- Did not add spice-vdagentd to hw-vm.nix due to conflict with task-vm-hardware.nix (both roles are used by griefling)
- Cleaned up invalid imports (fonts, theming) from modules/apps/default.nix that were causing build errors

## Issues Encountered
- modules/apps/default.nix had invalid imports for ./fonts and ./theming which don't exist in that directory
  - Resolution: Removed these imports; fonts.nix is in modules/common, theming is at top level
- Conflicting spice-vdagentd.enable values between hw-vm.nix and task-vm-hardware.nix
  - Resolution: Did not add spice-vdagentd to hw-vm.nix; left it managed by task-vm-hardware.nix (set to false by default)
- malphas host has SOPS secret issues (unrelated to this plan)
  - Resolution: Noted in verification; outside scope of current plan

## Deviations
- Auto-fixed invalid imports in modules/apps/default.nix (fonts, theming)
- Added global imports for modules/apps and modules/theming to roles/common.nix (necessary for enable options to work)
- Did not add spice-vdagentd to hw-vm.nix due to role conflict (deviation from Task 2 which suggested moving it)

## Next Step
Ready for 10-02-PLAN.md
