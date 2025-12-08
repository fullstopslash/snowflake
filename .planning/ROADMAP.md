# Roadmap: NixOS Multi-Host Configuration

## Overview

Transform the existing single-host NixOS flake into a scalable, self-managing multi-host configuration. Start with module architecture and host differentiation, add reusable disk configs, migrate secrets, expand to Darwin, enable auto-updates, then polish the new-host workflow.

## Phases

- [x] **Phase 1: Module Architecture** - Three-tier module system + host-spec pattern
- [ ] **Phase 2: Disko Integration** - Modular disk configurations by use-case
- [ ] **Phase 3: Secrets Migration** - Port to nix-secrets flake pattern
- [ ] **Phase 4: Darwin Support** - nix-darwin for MacBook, cross-platform modules
- [ ] **Phase 5: Auto-Updates** - Systemd timer for flake updates + rebuild
- [ ] **Phase 6: New Host Onboarding** - Template system, streamlined workflow

## Phase Details

### Phase 1: Module Architecture
**Goal**: Restructure modules into common (auto-applied), opt-in (subscribe), and host-specific tiers. Add host-spec pattern for declarative host differentiation.
**Depends on**: Nothing (first phase)
**Plans**: 3 plans

Plans:
- [x] 01-01: Host Specification Module - Create typed hostSpec options, wire into flake
- [x] 01-02: Module Directory Restructure - Create common/opt-in structure, move universal
- [x] 01-03: Malphas Migration & Validation - Update malphas, live rebuild test

### Phase 2: Disko Integration
**Goal**: Create reusable disko disk configurations for different use-cases (desktop, server, pi).
**Depends on**: Phase 1
**Plans**: TBD

Plans:
- [ ] 02-01: Create base disko configs (desktop-btrfs, server-zfs, pi-simple)
- [ ] 02-02: Integrate disko selection into host-spec

### Phase 3: Secrets Migration
**Goal**: Migrate from current sops setup to nix-secrets flake pattern. Clean separation of encrypted (sops) vs non-encrypted (nix-secrets) data.
**Depends on**: Phase 1 (needs host-spec for per-host secrets)
**Plans**: TBD

Plans:
- [ ] 03-01: Set up nix-secrets flake input and structure
- [ ] 03-02: Migrate existing secrets, update sops module

### Phase 4: Darwin Support
**Goal**: Add nix-darwin configuration for MacBook. Ensure modules gracefully handle Darwin vs NixOS.
**Depends on**: Phase 1 (host-spec.isDarwin)
**Plans**: TBD

Plans:
- [ ] 04-01: Add nix-darwin input, create darwin host structure
- [ ] 04-02: Audit modules for Darwin compatibility

### Phase 5: Auto-Updates
**Goal**: All hosts automatically update flake and rebuild on a schedule via systemd timer.
**Depends on**: Phases 1-4 (stable foundation needed)
**Plans**: TBD

Plans:
- [ ] 05-01: Create auto-update module with systemd timer
- [ ] 05-02: Add update notification/logging

### Phase 6: New Host Onboarding
**Goal**: Minimal friction for adding new machines. Clear template, docs, and workflow.
**Depends on**: All previous phases
**Plans**: TBD

Plans:
- [ ] 06-01: Create host template with minimal required config
- [ ] 06-02: Document onboarding workflow

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Module Architecture | 3/3 | Complete | 2025-12-08 |
| 2. Disko Integration | 0/2 | Not started | - |
| 3. Secrets Migration | 0/2 | Not started | - |
| 4. Darwin Support | 0/2 | Not started | - |
| 5. Auto-Updates | 0/2 | Not started | - |
| 6. New Host Onboarding | 0/2 | Not started | - |
