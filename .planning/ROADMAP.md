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
**Goal**: `/roles/` directory with base role files that define software modules and settings per device type
**Depends on**: Phase 1
**Plans**: TBD

Key work:
- Create role structure: desktop.nix, server.nix, pi.nix, darwin.nix, tablet.nix
- Migrate software modules from ~/nix/roles/ into role-appropriate files
- Each role imports relevant modules (gaming → desktop, headless → server, etc.)
- Roles set sensible defaults that hosts can override

### Phase 3: Host-Spec & Inheritance
**Goal**: Minimal host-spec where hosts just declare role + username + quirks; automatic inheritance with local overrides
**Depends on**: Phase 2
**Plans**: TBD

Key work:
- Redesign host-spec.nix for role-based inheritance
- Host default.nix: `role = "desktop"; primaryUser = "rain";` + quirks
- Automatic module resolution: host imports role, role imports modules
- Override pattern: files in host folder override role defaults
- Validate with empty host that inherits everything

### Phase 4: Secrets & Security
**Goal**: sops-nix working across all roles/hosts with secure key bootstrapping
**Depends on**: Phase 3
**Plans**: TBD

Key work:
- Set up sops-nix with age keys
- Per-host and shared secrets structure
- Secure bootstrapping for new machines
- Integration with roles (secrets needed by desktop vs server)

### Phase 5: Reference Host
**Goal**: Migrate malphas (main desktop) using new minimal host pattern
**Depends on**: Phase 4
**Plans**: TBD

Key work:
- Create minimal malphas/default.nix using role inheritance
- Migrate hardware-configuration.nix
- Validate all current functionality works
- Document the minimal host pattern
- Test override capability (host-specific quirks)

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

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 3/3 | Complete | 2025-12-08 |
| 2. Role System | 0/? | Not started | - |
| 3. Host-Spec & Inheritance | 0/? | Not started | - |
| 4. Secrets & Security | 0/? | Not started | - |
| 5. Reference Host | 0/? | Not started | - |
| 6. Auto-Update System | 0/? | Not started | - |
