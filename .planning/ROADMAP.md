# Roadmap: Unified Nix Homelab

## Overview

Transform two existing Nix repos into a unified multi-host flake with role-based inheritance. The goal is minimal host definitions (just role + username + quirks) that automatically inherit everything from role files, with full override capability. End state: add a new machine in under 10 minutes with auto-updating builds.

## Phases

- [ ] **Phase 1: Foundation** - Clean flake structure with multi-arch, merged lib/overlays
- [ ] **Phase 2: Role System** - Base roles (desktop, server, pi, darwin, tablet) defining software and settings
- [ ] **Phase 3: Host-Spec & Inheritance** - Minimal host definitions with automatic role inheritance
- [ ] **Phase 4: Secrets & Security** - sops-nix across roles/hosts with secure bootstrapping
- [ ] **Phase 5: Reference Host** - Migrate malphas, validate minimal host pattern
- [ ] **Phase 6: Auto-Update System** - Daily rebuilds, WoL-triggered updates, git pull automation
- [ ] **Phase 7: Structure Reorganization** - Unify modules, clean up hosts/common, rename home to home-manager
- [ ] **Phase 8: Role System Refinement** - Common role base, task-based roles, minimal host pattern
- [ ] **Phase 9: Griefling Minimal Fix** - Fix module imports so VM role is truly minimal

## Phase Details

### Phase 1: Foundation
**Goal**: Clean flake.nix with multi-arch support, unified lib and overlays from both repos
**Depends on**: Nothing (first phase)
**Plans**: 3 plans

Plans:
- [x] 01-01: Flake multi-arch structure (forAllSystems, mkHost helper)
- [x] 01-02: Lib & overlays consolidation (clean helpers, fix broken overrides)
- [x] 01-03: Build tooling integration (nh, disko, verification)

### Phase 2: Role System
**Goal**: `/roles/` with device-type roles, `/modules/` with migrated software modules from ~/nix
**Depends on**: Phase 1
**Plans**: 4 plans

Plans:
- [x] 02-01: Module migration structure (create dirs, migrate core/desktop modules)
- [x] 02-02: Module migration continued (development, services, fix imports)
- [x] 02-03: Role definitions (desktop, laptop, server, pi, tablet, darwin, vm)
- [x] 02-04: Integration & verification (wire up flake, test role system)

### Phase 3: Host-Spec & Inheritance
**Goal**: Minimal host-spec where hosts just declare role + username + quirks; automatic inheritance with local overrides
**Depends on**: Phase 2
**Plans**: 3 plans

Plans:
- [x] 03-01: Clean hostSpec & add role defaults (remove deprecated options, roles set hostSpec defaults)
- [x] 03-02: Module resolution (roles import optional modules, enable-gated pattern)
- [x] 03-03: Minimal host pattern (test host, verify inheritance, document override pattern)

### Phase 4: Secrets & Security
**Goal**: sops-nix working across all roles/hosts with secure key bootstrapping
**Depends on**: Phase 3
**Plans**: 4 plans

Plans:
- [x] 04-01: Audit & fix current SOPS setup (fix broken configs, add host-spec integration)
- [x] 04-02: Role-based secrets structure (secret categories, role defaults)
- [x] 04-03: Bootstrap & key management (streamline new host setup)
- [x] 04-04: Shared secrets & multi-host access (shared.yaml integration)

### Phase 5: Reference Host
**Goal**: Migrate ghost (main desktop) to minimal host pattern using role system
**Depends on**: Phase 4
**Plans**: 2 plans

Plans:
- [x] 05-01: Migrate ghost to role system (add roles.desktop, remove redundant imports)
- [x] 05-02: Clean up test hosts & document pattern (malphas, minimaltest, roletest)

### Phase 6: Auto-Update System
**Goal**: Self-updating machines via daily git pull + rebuild, or WoL-triggered updates
**Depends on**: Phase 5
**Plans**: 1 plan (done inline)

Completed work:
- [x] Created `modules/services/misc/auto-upgrade.nix` with full options
- [x] Two modes: `remote` (flake URL) and `local` (git pull + nh rebuild)
- [x] Configurable: schedule, flakeUrl, keepGenerations, keepDays, rebootWindow
- [x] Safety check: only upgrades if remote is newer than local
- [x] Integrated with nh for clean garbage collection
- [x] Enabled by default for server and pi roles
- [x] Removed duplicate config from nix-management.nix

Not implemented (optional future work):
- WoL integration (wake → pull → rebuild → sleep)
- Push notification (webhook triggers rebuild)
- Multi-remote git sync

### Phase 7: Structure Reorganization
**Goal**: Clean, unified module structure with minimal home-manager usage
**Depends on**: Phase 5 (working hosts)
**Plans**: 4 plans

Plans:
- [x] 07-01: Remove user `ta` (delete all ta-related files and references)
- [x] 07-02: Convert hosts/common/optional to modules (32 files → proper mkOption modules)
- [x] 07-03: Rename /home/ to /home-manager/ (clearer naming, restructure users/)
- [x] 07-04: Audit HM configs (audit confirmed HM usage is appropriate - no migration needed)

Key work:
- All option definitions in `/modules/` with mkOption/mkEnableOption
- `/hosts/common/` for truly universal configs only
- Features enabled via `myModules.*.enable = true` pattern
- `/home-manager/` only for HM-required configs (nixvim, dotfiles)
- Document why each remaining HM config is necessary

### Phase 8: Role System Refinement
**Goal**: Perfect the role system so hosts are super minimal (~15-30 lines). Add task-based roles for composition.
**Depends on**: Phase 7
**Plans**: 4 plans

Plans:
- [x] 08-01: Create roles/common.nix with universal config, refactor default.nix
- [x] 08-02: Add task-based roles (development, mediacenter) for composition
- [x] 08-03: Refactor hostSpec so roles set most values, hosts only set identity
- [x] 08-04: Migrate hosts to minimal pattern (griefling 286→204, malphas 47→42)

Key work:
- `roles/common.nix` with universal baseline all roles inherit
- Hardware roles (desktop, laptop, vm) + task roles (development, mediacenter)
- Roles compose: `roles.laptop + roles.development`
- hostSpec options categorized: identity (host sets) vs behavioral (role sets)
- Minimal host template: hardware-config + role + hostname + quirks

Target host pattern:
```nix
{ lib, ... }: {
  imports = [ ./hardware-configuration.nix ];
  roles.desktop = true;
  hostSpec.hostName = "myhost";
  system.stateVersion = "23.11";
}
```

### Phase 9: Griefling Minimal Fix (SUPERSEDED by Phase 10)
**Status**: Superseded - root cause analysis led to more comprehensive fix in Phase 10

### Phase 10: Griefling Speedup - Fix Unconditional Module Imports
**Goal**: Fix role system so griefling VM deploys in minutes, not ages. Reduce from 300+ packages to <100.
**Depends on**: Phase 8
**Plans**: 4 plans

Root cause analysis (performed 2025-12-12):
- `roles/default.nix` imports ALL role files (hw-*.nix, task-*.nix) unconditionally
- Role files have `imports = [...]` OUTSIDE their `lib.mkIf` blocks
- These imports pull in modules via `scanPaths ./` which loads all .nix files
- Modules like `plasma.nix`, `media/default.nix` have NO enable guards
- Result: griefling (roles.vm = true) gets full KDE Plasma 6, Jellyfin, Spotify, etc.

Evidence (griefling system-path):
- 300+ direct derivation inputs
- 39 KDE/Plasma packages (plasma-desktop, kwin, dolphin, konsole, etc.)
- 5 Jellyfin packages
- Spotify, VLC, quickemu

Plans:
- [ ] 10-01: Add enable options to plasma.nix, media/default.nix; move hw-desktop.nix imports inside mkIf
- [ ] 10-02: Fix remaining role files (hw-laptop, hw-tablet, task-mediacenter)
- [ ] 10-03: Audit all scanPaths directories, add enable guards to all modules
- [ ] 10-04: Create fast-test role, validate griefling closure <100 packages

Key patterns to apply:
1. Every module: `options.myModules.X.enable = lib.mkEnableOption "...";`
2. Every module: `config = lib.mkIf cfg.enable { ... };`
3. Role files: NO `imports = [...]` outside mkIf blocks
4. Roles: Use `myModules.X.enable = lib.mkDefault true;` to enable modules

Target griefling packages (after fix):
- Ly (display manager) + Hyprland
- Firefox, htop, curl, git
- Tailscale, Atuin, Syncthing
- NO: Plasma, KDE, Jellyfin, Spotify, VLC, Steam, Docker, LaTeX

### Phase 11: Architecture Reorganization
**Goal**: Clean three-tier architecture: /modules (settings), /hosts (minimal), /roles (meta-modules)
**Depends on**: Phase 10
**Plans**: 1 plan (done inline)

Target architecture:
```
/modules  - Pure settings only (mkOption/mkEnableOption)
            No role logic, just atomic configurable units
/hosts    - Super minimal (~15-30 lines)
            hardware-config + disk + role + hostname
/roles    - Meta-modules composing /modules
            Just enable options, no imports
```

Completed work:
- [x] Central module import in roles/common.nix (already done in Phase 10)
- [x] Removed redundant imports from form-pi.nix, form-server.nix, form-vm.nix, task-development.nix
- [x] Roles only set `myModules.*.enable = true` - no more top-level imports
- [x] Fixed SOPS hasSecrets check in modules/users/default.nix
- [x] Added template host hardware-configuration.nix and disk config

### Phase 12: Unified Module Selection System
**Goal**: List-based module selection with LSP autocompletion. Roles and hosts use same syntax.
**Depends on**: Phase 11
**Plans**: 4 plans + extension

Transform module selection from:
```nix
myModules.desktop.plasma.enable = lib.mkDefault true;
myModules.apps.media.enable = lib.mkDefault true;
```

To unified list-based selection:
```nix
modules = {
  desktop = lib.mkDefault [ "plasma" "hyprland" "wayland" ];
  apps = lib.mkDefault [ "media" "gaming" ];
  development = lib.mkDefault [ "latex" "containers" ];
};
```

Transform role selection from:
```nix
roles.vm = true;
roles.test = true;
```

To unified list-based selection:
```nix
roles = [ "vm" "test" "secretManagement" ];
extraModules.apps = [ "productivity" ];  # Additive to role defaults
```

Key features:
- LSP autocompletion via `lib.types.enum` for both roles and modules
- Roles are "selection presets" - same list syntax as hosts
- hostSpec behavioral options derived from selections (useWayland, isDevelopment, etc.)
- Hosts inherit from roles, can extend with `extraModules.*` or override with `lib.mkForce`

Plans:
- [x] 12-01: Selection system foundation (lib/modules.nix, modules/selection.nix)
- [x] 12-02: hostSpec simplification (derive behavioral options from selections)
- [x] 12-03: Role migration (convert all roles to selection syntax)
- [x] 12-04: Host migration & validation (malphas, griefling, documentation)
- [x] 12-05: List-based role selection (roles = [...], extraModules.* for additive selections)

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 3/3 | Complete | 2025-12-08 |
| 2. Role System | 4/4 | Complete | 2025-12-08 |
| 3. Host-Spec & Inheritance | 3/3 | Complete | 2025-12-08 |
| 4. Secrets & Security | 4/4 | Complete | 2025-12-08 |
| 5. Reference Host | 2/2 | Complete | 2025-12-08 |
| 6. Auto-Update System | 1/1 | Complete | 2025-12-12 |
| 7. Structure Reorganization | 4/4 | Complete | 2025-12-11 |
| 8. Role System Refinement | 4/4 | Complete | 2025-12-11 |
| 9. Griefling Minimal Fix | - | Superseded | - |
| 10. Griefling Speedup | 4/4 | Complete | 2025-12-12 |
| 11. Architecture Reorganization | 1/1 | Complete | 2025-12-12 |
| 12. Unified Module Selection | 5/5 | Complete | 2025-12-13 |
