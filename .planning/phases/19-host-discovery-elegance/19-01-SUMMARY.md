# Phase 19 Plan 1: Declarative Host Behavior Summary

**Made host behavior declarative and eliminated hardcoded host logic from flakes**

## Accomplishments

- Added `architecture`, `nixpkgsVariant`, and `useCustomPkgs` options to host-spec module
- Roles now set architecture defaults (desktop/laptop/server: x86_64-linux, pi: aarch64-linux, vm: x86_64-linux + unstable)
- Refactored mkHost to read architecture and nixpkgsVariant from host configs instead of hardcoded lists
- Eliminated hardcoded testVMs list from main flake.nix
- Auto-discovery in nixos-installer reads host configs for disk layout, architecture, and swap settings
- Created install-host helper script embedded in ISO for one-command installations
- All hosts evaluate and build successfully with declarative behavior

## Files Created/Modified

- `modules/common/host-spec.nix` - Added architecture, nixpkgsVariant, useCustomPkgs options in IDENTITY section
- `roles/form-desktop.nix` - Set architecture = x86_64-linux, nixpkgsVariant = stable
- `roles/form-vm.nix` - Set architecture = x86_64-linux, nixpkgsVariant = unstable
- `roles/form-laptop.nix` - Set architecture = x86_64-linux
- `roles/form-server.nix` - Set architecture = x86_64-linux
- `roles/form-pi.nix` - Set architecture = aarch64-linux
- `flake.nix` - Refactored mkHost to read behavior from config, removed hardcoded testVMs list
- `nixos-installer/flake.nix` - Auto-discover hosts from ../hosts/, extract disk/architecture from configs
- `nixos-installer/install-host.sh` - Created helper script for guided installations
- `nixos-installer/minimal-configuration.nix` - Added install-host script, neovim, btrfs-progs, bcachefs-tools

## Decisions Made

- Used direct import approach for preliminary config evaluation (simple and reliable)
- ISO host handled specially with hardcoded defaults to avoid module evaluation complexity
- install-host script embedded inline in minimal-configuration.nix using writeScriptBin (avoids file path issues)
- Disk config (layout, device, withSwap, swapSize) already exists in host configs - no new options needed
- Architecture and nixpkgsVariant belong in IDENTITY section (define what host IS, not how it behaves)

## Issues Encountered

- Initial two-pass evaluation approach caused infinite recursion and module argument issues
- Resolved by using simple direct import of host config to extract roles and hostSpec values
- ISO host required special handling since it's a proper NixOS module, not a simple attrset
- install-host.sh needed to be inline in nix expression to avoid file path issues in flake evaluation

## Next Step

Ready for 19-02-PLAN.md (Rename hostSpec → host)
