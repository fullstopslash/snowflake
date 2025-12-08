# NixOS Multi-Host Configuration

**One-liner**: Self-managing, flake-based NixOS configuration for 3-15 heterogeneous hosts with minimal friction for new machines.

## Problem

Current config works but lacks structure for scaling to many hosts. Adding a new machine requires too much boilerplate. No consistent patterns for: host differentiation, disk configuration reuse, module subscription, or automated updates. Secrets management needs migration to nix-secrets pattern.

## Success Criteria

How we know it worked:

- [ ] New host onboarding requires only: hostname, hardware-configuration.nix, and a list of subscribed modules
- [ ] Disko configs are reusable by use-case (desktop, server, pi, etc.)
- [ ] Three-tier module system works: common (auto), opt-in (subscribe), host-specific
- [ ] All hosts auto-update via systemd timer
- [ ] Secrets managed via nix-secrets flake pattern
- [ ] MacBook (darwin) supported alongside NixOS hosts

## Constraints

- Must remain a single flake (not split repos)
- Preserve existing working malphas configuration during migration
- Sops-nix for encrypted secrets (nix-secrets for non-encrypted config data)
- Support x86_64-linux, aarch64-linux (Pi), aarch64-darwin (MacBook)

## Out of Scope

- Home-manager (defer to future iteration)
- Impermanence/tmpfs root (not needed now)
- Remote deployment tooling like deploy-rs (manual rebuild is fine initially)
- Colmena/morph orchestration
