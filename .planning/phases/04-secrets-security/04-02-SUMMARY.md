# Phase 4 Plan 2: Role-Based Secrets Structure - Summary

**Roles now automatically enable appropriate secret categories; secrets organized by purpose**

## Accomplishments

1. **Added secretCategories to hostSpec**
   - `base`: user passwords, age keys, msmtp (default: true)
   - `desktop`: home assistant, desktop app secrets
   - `server`: backup credentials, service secrets
   - `network`: tailscale, VPN configs

2. **Created modular sops directory structure**
   - `hosts/common/core/sops/default.nix` - orchestrates categories
   - `hosts/common/core/sops/base.nix` - base secrets
   - `hosts/common/core/sops/desktop.nix` - desktop secrets
   - `hosts/common/core/sops/server.nix` - server secrets
   - `hosts/common/core/sops/network.nix` - network secrets

3. **Updated roles to set secret categories**
   - Desktop role: base + desktop + network
   - Laptop role: base + desktop + network (same as desktop)
   - Server role: base + server + network
   - VM role: base only

## Files Created

| File | Purpose |
|------|---------|
| `hosts/common/core/sops/default.nix` | Main orchestrator, imports categories |
| `hosts/common/core/sops/base.nix` | User password, age key, msmtp |
| `hosts/common/core/sops/desktop.nix` | Home assistant secrets |
| `hosts/common/core/sops/server.nix` | Borg backup, service credentials |
| `hosts/common/core/sops/network.nix` | Tailscale OAuth |

## Files Modified

| File | Change |
|------|--------|
| `modules/common/host-spec.nix` | Added secretCategories option |
| `hosts/common/core/default.nix` | Import sops/ directory instead of sops.nix |
| `roles/desktop.nix` | Set secretCategories (base, desktop, network) |
| `roles/laptop.nix` | Set secretCategories (base, desktop, network) |
| `roles/server.nix` | Set secretCategories (base, server, network) |
| `roles/vm.nix` | Set secretCategories (base only) |
| `modules/services/desktop/common.nix` | Use desktop category for HASS secrets |

## Files Removed

| File | Reason |
|------|--------|
| `hosts/common/core/sops.nix` | Replaced by sops/ directory |

## Verification Results

| Host | Role | Categories |
|------|------|------------|
| genoa | laptop | base, desktop, network |
| minimaltest | desktop | base, desktop, network |
| iso | none | base only (default) |

## Secret Category Contents

| Category | Secrets |
|----------|---------|
| **base** | keys/age, passwords/${username}, passwords/msmtp |
| **desktop** | env_hass_server, env_hass_token |
| **server** | passwords/borg, keys/ssh/borg |
| **network** | tailscale/oauth_client_id, tailscale/oauth_client_secret |

## Architecture

```
hostSpec.secretCategories = {
  base = true;      # Always true by default
  desktop = false;  # Set by desktop/laptop roles
  server = false;   # Set by server role
  network = false;  # Set by roles with network needs
};

hosts/common/core/sops/
├── default.nix     # Core sops config + imports
├── base.nix        # lib.mkIf (hasSecrets && base)
├── desktop.nix     # lib.mkIf (hasSecrets && desktop)
├── server.nix      # lib.mkIf (hasSecrets && server)
└── network.nix     # lib.mkIf (hasSecrets && network)
```

## Adding New Secrets

1. Determine which category the secret belongs to
2. Add to appropriate `hosts/common/core/sops/*.nix` file
3. If new category needed, create new file and add to default.nix imports
4. Secrets automatically available to hosts with that category enabled

## Next Steps

Plan 04-03: Bootstrap & key management (streamline new host setup)
