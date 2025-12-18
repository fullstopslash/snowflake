# Roadmap: Unified Nix Homelab

## Overview

Transform two existing Nix repos into a unified multi-host flake with role-based inheritance. The goal is minimal host definitions (just role + username + quirks) that automatically inherit everything from role files, with full override capability. End state: add a new machine in under 10 minutes with auto-updating builds.

## Phases

- [x] **Phase 1: Foundation** - Clean flake structure with multi-arch, merged lib/overlays
- [x] **Phase 2: Role System** - Base roles (desktop, server, pi, darwin, tablet) defining software and settings
- [x] **Phase 3: Host-Spec & Inheritance** - Minimal host definitions with automatic role inheritance
- [x] **Phase 4: Secrets & Security** - sops-nix across roles/hosts with secure bootstrapping
- [x] **Phase 5: Reference Host** - Migrate malphas, validate minimal host pattern
- [x] **Phase 6: Auto-Update System** - Daily rebuilds, WoL-triggered updates, git pull automation
- [x] **Phase 7: Structure Reorganization** - Unify modules, clean up hosts/common, rename home to home-manager
- [x] **Phase 8: Role System Refinement** - Common role base, task-based roles, minimal host pattern
- [ ] **Phase 9: Griefling Minimal Fix** - (Superseded by Phase 10)
- [x] **Phase 10: Griefling Speedup** - Fix unconditional module imports, reduce package count
- [x] **Phase 11: Architecture Reorganization** - Clean three-tier: /modules, /hosts, /roles
- [x] **Phase 12: Unified Module Selection** - List-based selection with LSP autocompletion
- [x] **Phase 13: Filesystem-Driven Selection** - Auto-generate options from /modules filesystem
- [x] **Phase 14: Role Elegance Audit** - Remove redundant enables, enforce selection-only pattern
- [x] **Phase 15: Self-Managing Infrastructure** - Golden boot entries, decentralized GitOps, auto-rollback
- [x] **Phase 16: SOPS/Age Key Management** - Pre-Phase-17 key setup, distribution, encryption testing
- [x] **Phase 17: Physical Security & Recovery** - LUKS encryption, device stolen runbook, glass-key disaster recovery
- [x] **Phase 18: GitOps Test Infrastructure** - Decentralized GitOps testing and validation
- [x] **Phase 19: Host Discovery & Flake Elegance** - Auto-discover hosts, rename hostSpec → host
- [x] **Phase 20: Bcachefs Native Encryption** - ChaCha20/Poly1305 encryption, boot unlock automation
- [ ] **Phase 21: TPM Unlock** - TPM2 automatic unlock for bcachefs with Clevis, manual fallback **[BLOCKED]**
- [ ] **Phase 22: Home Manager Cleanup** - Separate installation from configuration, move desktop/browsers to modules/apps

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

### Phase 13: Filesystem-Driven Module Selection
**Goal**: Auto-generate selection options from /modules filesystem. Selection paths mirror filesystem structure.
**Depends on**: Phase 12
**Plans**: 1 plan

Key implementation:
- `modules/selection.nix` scans `/modules/apps/` and `/modules/services/` directories
- Options auto-generated: `modules.services.<category> = [ "module-names" ]`
- Translation layer converts selections to `myModules.<top>.<category>.<module>.enable = true`
- `extraModules.*` provides additive selection for hosts
- No manual list updates when adding new modules - just create the .nix file

Plans:
- [x] 13-01: Implement filesystem-driven selection with auto-generated options

### Phase 14: Role Elegance Audit
**Goal**: Ensure roles ONLY use unified module selection. Remove redundant direct enables.
**Depends on**: Phase 13
**Plans**: 1 plan

Audit findings:
- Some roles still use `services.openssh.enable` alongside `modules.services.networking = [ "openssh" ]`
- Some roles use direct `myModules.*.enable` instead of `modules.*` selection syntax
- Hardware/boot config (no corresponding modules) is legitimate

Key patterns enforced:
1. Roles use `modules.<top>.<category> = [ "name" ]` for all module enables
2. Direct NixOS options only for hardware/boot with no module wrapper
3. Direct `myModules.*.enable` only for modules outside selection system (`modules/common/`)

Plans:
- [x] 14-01: Remove redundant enables from form-pi.nix, form-server.nix; convert task-test.nix to selection

### Phase 15: Self-Managing Infrastructure
**Goal**: Enable safe decentralized GitOps with golden boot entries, pre-update validation, and automatic rollback.
**Depends on**: Phase 6 (Auto-Update), Phase 14 (Clean role system)
**Plans**: 3 plans

Vision: Each host can commit changes to the repo, all hosts pull and validate before rebuilding. If an update fails, automatic rollback to the last known-good "golden" generation. This enables true decentralized self-management where any host can evolve the config safely.

Current state (from Phase 6):
- ✅ Auto-upgrade module with git pull + rebuild
- ✅ SSH keys deployed via SOPS for git push
- ✅ Daily rebuild schedule
- ⏳ No golden boot entry protection
- ⏳ No pre-update validation
- ⏳ No automatic rollback on failure

Key components to add:
1. **Golden Boot Entry System** - Pin known-good builds that survive GC
2. **Pre-Update Validation** - Build before switch, verify before deploy
3. **Decentralized GitOps Safety** - Commit automation, conflict handling, rollback
4. **Systemd Watchdog** - Detect boot failures, auto-revert to golden

Safety flow:
```
1. Pin current working config as "golden" (after 24h stable uptime)
2. Git pull new changes
3. Build (don't switch yet)
4. If build succeeds → switch
5. If boot succeeds (systemd watchdog) → confirm
6. If boot fails → automatic rollback to golden
```

Plans:
- [x] 15-01: Golden boot entry module (auto-pin after stable uptime, manual pin command, GC protection)
- [x] 15-02: Pre-update validation (build-before-switch in auto-upgrade, validation checks, rollback on build failure)
- [x] 15-03: Decentralized GitOps safety (git push for hosts, pre-update commit automation, systemd watchdog, boot failure rollback)

Target for hosts:
- Server/Pi: Auto-pin golden after 24h uptime
- All hosts: Build validation before switch
- All hosts: Automatic rollback on boot failure
- Optional: Host can commit and push changes (for true decentralized management)

### Phase 16: SOPS/Age Key Management
**Goal**: Enforce SOPS/age key hygiene and enable safe manual key rotation with Jujutsu workflow support
**Depends on**: Phase 4 (Secrets & Security), Phase 15 (Self-Managing Infrastructure)
**Plans**: 3 plans

Background: Current SOPS implementation has no enforcement of key permissions, format validation, or rotation capabilities. Keys are generated once at bootstrap and never rotated. VCS operations hardcoded to git, need jujutsu support.

Plans:
- [ ] 16-01: SOPS key enforcement module (validate permissions, format, secret decryption)
- [ ] 16-02: Jujutsu VCS integration (vcs-helpers.sh abstraction, update bootstrap/rekey)
- [ ] 16-03: Key rotation foundation (metadata tracking, rotation helpers, manual workflow)

Key work:
- **Enforcement Module** at `modules/security/sops-enforcement.nix`:
  - Assertions for SSH host key existence
  - Activation script to validate/fix key permissions (600)
  - Systemd service to verify secret decryption success
  - Auto-enable when `hostSpec.hasSecrets = true`
- **VCS Abstraction** at `scripts/vcs-helpers.sh`:
  - Functions: vcs_add, vcs_commit, vcs_push, vcs_pull
  - Environment variable `VCS_TYPE` (default: jj, fallback: git)
  - Update justfile rekey, bootstrap, and helpers.sh
- **Rotation Infrastructure**:
  - Key age metadata tracking in host secrets
  - Zero-downtime rotation process (7 steps)
  - Helper functions in `scripts/sops-rotate.sh`
  - Justfile commands: `sops-rotate`, `sops-check-key-age`
  - Documentation at `docs/sops-rotation.md`

Target outcome:
- Keys validated at every rebuild (permissions, format, decryption)
- Jujutsu-first workflow for SOPS operations
- Manual rotation ready with zero-downtime process
- Foundation for physical security measures

### Phase 17: Physical Security & Disaster Recovery
**Goal**: Protect against physical device theft and enable total infrastructure recovery from glass-key backups
**Depends on**: Phase 16 (SOPS key management)
**Plans**: 3 plans
**Status**: Complete (Infrastructure ready, tested on misery VM)

Plans:
- [x] 17-01: LUKS Full Disk Encryption Infrastructure
  - Removed FIDO2/YubiKey hardcoded requirement from LUKS modules
  - Password-only unlock by default (YubiKey optional post-install)
  - Updated both legacy installer and new module system
  - Comprehensive migration guide created (`docs/luks-migration.md`)
  - Optional YubiKey enrollment guide created (`docs/yubikey-enrollment.md`)
  - Host disk audit completed (all hosts cataloged)
  - Tested on misery VM with `btrfs-luks-impermanence` layout
  - Infrastructure ready for physical host migration when needed

- [x] 17-02: Device Stolen Response Runbook
  - Comprehensive incident response procedures for physical device theft
  - < 1 hour response time target for key rotation
  - 5-phase response timeline (immediate, key rotation, secret rotation, monitoring, post-incident)
  - Secret rotation priority matrix (Tailscale, API tokens, passwords)
  - 7-day monitoring procedures with anomaly detection
  - Post-incident review template with formal incident report
  - Printable quick reference card for emergency offline access
  - Complete runbook created (`docs/incident-response/device-stolen.md`)
  - Quick reference created (`docs/incident-response/QUICK-REFERENCE.md`)

- [x] 17-03: Glass-Key Disaster Recovery System
  - Master age key documentation for total infrastructure recovery
  - Physical backups documentation: paper, metal, encrypted USB
  - Offline git bundles (no GitHub dependency)
  - Complete recovery procedure from catastrophic loss
  - Maintenance schedule (monthly/quarterly/annual testing)
  - Automated backup script created (`scripts/create-glass-key-backup.sh`)
  - Comprehensive documentation (6 guides, 3,078 lines)
  - **Status**: Documentation complete, implementation awaiting user action

Target outcome (achieved for all Phase 17 plans):
- ✅ LUKS infrastructure ready and tested
- ✅ Password-only unlock (no YubiKey required)
- ✅ Comprehensive LUKS migration documentation created
- ✅ Misery VM validates LUKS + impermanence combination
- ✅ Age keys will be protected when LUKS is deployed
- ✅ Device stolen incident response runbook complete
- ✅ < 1 hour response time procedures documented
- ✅ Quick reference card ready for offline emergency use
- ✅ Glass-key disaster recovery system documented and scripted
- ✅ Total infrastructure recoverable from physical backups alone

### Phase 18: GitOps Test Infrastructure
**Goal**: Test infrastructure for validating decentralized GitOps workflows
**Depends on**: Phase 15 (Self-Managing Infrastructure)
**Plans**: 1 plan

Plans:
- [x] 18-01: GitOps test infrastructure setup and validation

### Phase 19: Host Discovery & Flake Elegance
**Goal**: Auto-discover hosts, simplify flake configuration, rename hostSpec to host for clearer boundaries
**Depends on**: Phase 16 (SOPS/Age Key Management)
**Plans**: 3 plans

Vision: Eliminate manual host declarations in flakes. Make host behavior declarative in host configs. Create elegant, minimal, streamlined `host` module (parallel to `modules` and `roles`) that's obvious and easy to parse at a glance. Single-command installs from ISO with embedded config.

Current pain points:
- mkHost has hardcoded testVMs list and conditional logic
- nixos-installer/flake.nix manually declares hosts
- hostSpec is large (300 lines) with mixed concerns
- Three-tier system (/roles, /modules, /hosts) boundaries unclear

Plans:
- [x] 19-01: Declarative host behavior (add architecture/nixpkgs options, simplify mkHost, auto-discover installer)
- [x] 19-02: Rename hostSpec → host (create elegant structure, mass migration of 37+ files)
- [x] 19-03: Cleanup & verification (remove old module, embed config in ISO, documentation)

Target outcome:
- Auto-discovery: Just create /hosts/hostname/ directory, no flake declarations needed
- Declarative: Host behavior explicit in host config, not hardcoded in flakes
- Elegant host module: Clear categories (identity/hardware/preferences), parallel to modules/roles
- ISO installer: Embedded nix-config, install-host command, single-step recovery installs
- Security: No secrets in ISO (bootstrapped post-install)
- Three-tier clarity: /roles (presets), /modules (units), /hosts (identity)

### Phase 20: Bcachefs Native Encryption
**Goal**: Implement bcachefs native ChaCha20/Poly1305 encryption with boot unlock automation
**Depends on**: Phase 17 (Physical Security & Recovery)
**Plans**: 3 plans (1 research + 2 implementation)

Vision: Provide bcachefs native encryption as a superior alternative to LUKS block-layer encryption. Bcachefs authenticated encryption provides encryption chain of trust and metadata integrity verification. Keep existing LUKS options for compatibility with traditional tooling.

Key challenges:
- systemd-cryptenroll doesn't support bcachefs (as of 2025-03)
- Requires custom boot unlock automation
- Disko bcachefs encryption configuration patterns need investigation
- Integration with Phase 17 password management infrastructure

Plans:
- [x] 20-01: Research bcachefs encryption (FINDINGS.md: disko patterns, boot unlock, key management)
- [x] 20-02: Native encryption layouts (bcachefs-encrypt, bcachefs-encrypt-impermanence)
- [x] 20-03: Boot integration & key management (systemd units, ISO installer support)

Target outcome:
- Native encryption layouts: bcachefs-encrypt and bcachefs-encrypt-impermanence
- Automatic boot unlock via systemd units (custom, not cryptenroll)
- Phase 17 password infrastructure integration maintained
- ISO installer supports bcachefs encryption workflows
- Clear documentation: when to use native vs LUKS encryption
- Superior security: authenticated encryption chain vs block-layer encryption
- Existing LUKS options preserved for traditional tooling compatibility

### Phase 21: TPM Unlock
**Goal**: Implement TPM2 automatic unlock for bcachefs native encryption using Clevis with fallback to interactive password
**Depends on**: Phase 20 (Bcachefs Native Encryption)
**Status**: Planning (2 plans: 1 blocked, 1 ready to execute)

**Solution**: Use nixpkgs bcachefs.nix patterns (verified at FOSDEM 2024)
- Add tpm_crb kernel module to initrd
- Use boot.initrd.systemd.contents instead of boot.initrd.secrets
- Generate Clevis token during installation (not post-boot)
- Tested on anguish VM with TPM emulation

Plans:
- [ ] 21-01: Initial attempt using custom systemd service (blocked by boot.initrd.secrets limitations)
- [ ] 21-02: Revised implementation using nixpkgs patterns (ready to execute)

Target outcome:
- Custom initrd systemd service for bcachefs + Clevis TPM unlock
- Automatic unlock when host.encryption.tpm.enable = true and token exists
- Robust fallback to systemd-ask-password for manual entry
- Per-host TPM configuration via hostSpec
- Servers boot unattended, laptops remain interactive
- Clevis package included in initrd when TPM enabled
- Kernel keyring linking handled properly

### Phase 22: Home Manager Cleanup
**Goal**: Reorganize home-manager to separate package installation from user configuration
**Depends on**: Nothing (independent cleanup phase)
**Plans**: 1 plan

Vision: Align desktop environment and browser management with the consistent module selection pattern used throughout the repo. Move package installations to modules/apps/ where they follow the standard myModules.apps.* enable pattern, while keeping only genuine user-level configuration (dotfiles, programs.* settings) in home-manager.

Current issues:
- Desktop environments (Hyprland) installed via home-manager, not modules/apps/
- Browsers (Firefox, Brave, Chromium) installed via home-manager, not modules/apps/
- Desktop utilities (rofi, waybar, dunst) installed via home-manager
- Inconsistent with repo-wide pattern where apps are enabled via myModules.apps.*
- Hard to understand what belongs in home-manager vs modules

Plans:
- [ ] 22-01: Reorganize home-manager (create window-manager/browser/utility modules, update home-manager files, test)

Target outcome:
- Package installation: modules/apps/window-managers/, modules/apps/desktop/, modules/apps/browsers/
- User configuration: home-manager/ (programs.firefox policies, Hyprland user scripts, XDG settings)
- Consistent module selection: myModules.apps.{category}.{app}.enable across all apps
- Clear documentation: README in home-manager/ explaining the separation
- Desktop role enables appropriate modules automatically
- No functionality lost, everything still works the same for users

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
| 13. Filesystem-Driven Selection | 1/1 | Complete | 2025-12-13 |
| 14. Role Elegance Audit | 1/1 | Complete | 2025-12-13 |
| 15. Self-Managing Infrastructure | 3/3 | Complete | 2025-12-15 |
| 16. SOPS/Age Key Management | 3/3 | Complete | 2025-12-15 |
| 17. Physical Security & Recovery | 3/3 | Complete | 2025-12-16 |
| 18. GitOps Test Infrastructure | 1/1 | Complete | 2025-12-16 |
| 19. Host Discovery & Flake Elegance | 3/3 | Complete | 2025-12-16 |
| 20. Bcachefs Native Encryption | 3/3 | Complete | 2025-12-17 |
| 21. TPM Unlock | 0/1 | Planning | - |
| 22. Home Manager Cleanup | 0/1 | Planning | - |
