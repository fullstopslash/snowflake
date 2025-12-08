# Unified Nix Homelab

**One-liner**: Multi-host Nix flake repo managing an entire homelab with minimal host definitions and self-updating machines.

## Problem

Managing diverse hardware (desktops, laptops, Pi, tablets, NAS, MacBook) across a homelab is fragmented and error-prone. Adding new machines requires too much boilerplate. Configurations drift between devices. Two existing repos exist: `~/nix` (working system with preferred configs/roles) and `~/nix-config` (better flake architecture but opinionated).

## Success Criteria

How we know it worked:

- [ ] New machine deployable in under 10 minutes with minimal host-spec file
- [ ] Secrets managed securely across all hosts via sops-nix
- [ ] Auto-updating machines: daily git pull + rebuild, or wake-on-LAN triggered rebuilds
- [ ] Multi-arch support working: x86_64 (AMD/Intel), aarch64 (Pi/tablets), T2 MacBook
- [ ] Fundamental settings shared; hosts can fully override any defaults
- [ ] Roles pattern from ~/nix preserved (flat, composable role files)
- [ ] Repo mirrors to GitHub, self-hosted git, Codeberg for redundancy

## Constraints

- **nh** for rebuilds (not nixos-rebuild directly)
- **disko** for declarative disk partitioning
- **sops-nix** for secrets (not agenix)
- **home-manager**: only when NixOS modules can't do it
- **Architectures**: x86_64-linux, aarch64-linux, x86_64-darwin (T2 MacBook)
- **Source repos**: Merge ~/nix (configs/apps/roles) into ~/nix-config (flake structure)

## Out of Scope

- Enterprise multi-user patterns (this is single-user homelab)
- Kubernetes/container orchestration beyond basic Podman/Docker
- Remote build farms (local builds only for now)
- Custom ISO generation (can add later)
- CI/CD pipelines (manual or cron-based updates)
