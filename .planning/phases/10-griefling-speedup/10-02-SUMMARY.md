# Phase 10 Plan 2: Fix Remaining Role Files Summary

**Converted remaining role files to enable-gated pattern, added enable guards to niri and flatpak modules**

## Accomplishments
- Removed top-level imports from form-laptop.nix, form-tablet.nix, and task-mediacenter.nix
- Added enable options to niri.nix and flatpak.nix modules
- All modified role files now use enable-based module activation
- Verified all modified files parse correctly with nix-instantiate

## Files Created/Modified
- `roles/form-laptop.nix` - Removed top-level imports section, added enable options for desktop modules (plasma, hyprland, wayland, media, gaming, development, CLI tools)
- `roles/form-tablet.nix` - Removed top-level imports section, added enable options for desktop modules (wayland, media, CLI shell)
- `roles/task-mediacenter.nix` - Removed top-level imports section, added enable option for media module
- `modules/services/desktop/niri.nix` - Added myModules.desktop.niri.enable option and wrapped all config in mkIf block
- `modules/services/misc/flatpak.nix` - Added myModules.services.flatpak.enable option and wrapped all config in mkIf block

## Decisions Made
- Aligned form-laptop.nix with form-desktop.nix pattern: included all desktop software stack (gaming, development tools, CLI tools)
- For form-tablet.nix: kept minimal set of modules (wayland, media, shell) appropriate for a tablet device
- For task-mediacenter.nix: only enabled media module; audio modules imported globally in common.nix
- Used myModules.desktop.niri namespace for niri module (consistent with other desktop modules)
- Used myModules.services.flatpak namespace for flatpak module (consistent with other service modules)

## Issues Encountered
- nix flake check failed due to unrelated SOPS secrets issue with malphas host (same as noted in 10-01-SUMMARY.md)
  - Resolution: Verified all modified files parse correctly using nix-instantiate instead
- Some role files still have top-level imports (form-pi.nix, form-server.nix, form-vm.nix, task-development.nix)
  - Resolution: These are out of scope for this plan; will be addressed in future plans if needed

## Deviations
- None. All tasks completed as specified in the plan.
- Adjusted for hw-*.nix to form-*.nix filename rename as instructed.

## Verification Results
- All syntax checks passed:
  - form-laptop.nix: PASS
  - form-tablet.nix: PASS
  - task-mediacenter.nix: PASS
  - niri.nix: PASS
  - flatpak.nix: PASS
- Top-level import checks passed:
  - form-laptop.nix: PASS (no top-level imports)
  - form-tablet.nix: PASS (no top-level imports)
  - task-mediacenter.nix: PASS (no top-level imports)
- Enable option checks passed:
  - niri.nix: PASS (has mkEnableOption)
  - flatpak.nix: PASS (has mkEnableOption)

## Success Criteria Status
- [x] form-laptop.nix has no top-level imports
- [x] form-tablet.nix has no top-level imports
- [x] task-mediacenter.nix has no top-level imports
- [x] All desktop/misc modules have enable guards (niri, flatpak)
- [x] All modified files parse correctly
- [ ] nix flake check passes (blocked by unrelated malphas SOPS issue)

## Next Steps
- Continue with phase 10 if there are more plans
- Address remaining role files (form-pi, form-server, form-vm, task-development) in future plans if needed
- Consider adding enable guards to audio modules (pipewire.nix, tuning.nix) in future plans
