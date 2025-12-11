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
**Plans**: TBD

Key work:
- systemd timer for daily git pull + nh rebuild
- WoL integration: wake → pull → rebuild → sleep
- Push notification option (webhook triggers rebuild)
- Multi-remote git sync (GitHub, Codeberg, self-hosted)
- Rollback safety (keep N generations)

### Phase 7: Structure Reorganization
**Goal**: Clean, unified module structure with minimal home-manager usage
**Depends on**: Phase 5 (working hosts)
**Plans**: 4 plans

Plans:
- [x] 07-01: Remove user `ta` (delete all ta-related files and references)
- [ ] 07-02: Convert hosts/common/optional to modules (32 files → proper mkOption modules)
- [ ] 07-03: Rename /home/ to /home-manager/ (clearer naming, restructure users/)
- [ ] 07-04: Migrate HM configs to NixOS (minimize home-manager, use NixOS where possible)

Key work:
- All option definitions in `/modules/` with mkOption/mkEnableOption
- `/hosts/common/` for truly universal configs only
- Features enabled via `myModules.*.enable = true` pattern
- `/home-manager/` only for HM-required configs (nixvim, dotfiles)
- Document why each remaining HM config is necessary

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 3/3 | Complete | 2025-12-08 |
| 2. Role System | 4/4 | Complete | 2025-12-08 |
| 3. Host-Spec & Inheritance | 3/3 | Complete | 2025-12-08 |
| 4. Secrets & Security | 4/4 | Complete | 2025-12-08 |
| 5. Reference Host | 2/2 | Complete | 2025-12-08 |
| 6. Auto-Update System | 0/? | Not started | - |
| 7. Structure Reorganization | 1/4 | In progress | - |
