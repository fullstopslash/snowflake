# Phase 4 Plan 4: Shared Secrets & Multi-Host Access - Summary

**Shared secrets accessible by all hosts with role-based access patterns**

## Accomplishments

1. **Created shared.nix module**
   - Added to sops/ directory imports
   - Framework for cross-host secrets
   - Documents how shared secrets work

2. **Integrated shared.yaml validation**
   - Assertion in default.nix verifies shared.yaml exists
   - All hosts with hasSecrets can access shared.yaml
   - Base secrets (passwords) already use shared.yaml

3. **Added role-based secret hints**
   - `sops_role_hints` function shows required secrets per role
   - `sops_verify_host_secrets` validates secrets exist
   - Helps during bootstrap know what secrets to create

4. **Updated bootstrap script integration**
   - `sops_add_shared_creation_rules` adds new hosts to shared.yaml
   - New hosts automatically get access to shared secrets
   - Documentation covers shared secrets workflow

## Files Created

| File | Purpose |
|------|---------|
| `hosts/common/core/sops/shared.nix` | Shared secrets loader module |

## Files Modified

| File | Change |
|------|--------|
| `hosts/common/core/sops/default.nix` | Import shared.nix, add shared.yaml assertion |
| `scripts/helpers.sh` | Add role hints and verification functions |

## Shared Secrets Architecture

```
nix-secrets/sops/
├── shared.yaml          # Secrets for ALL hosts
│   ├── passwords/rain   # User password
│   └── passwords/msmtp  # Mail password
├── genoa.yaml           # Host-specific secrets
└── malphas.yaml         # Host-specific secrets

hosts/common/core/sops/
├── default.nix          # Validates shared.yaml exists
├── base.nix             # Loads passwords from shared.yaml
├── desktop.nix          # Host-specific desktop secrets
├── server.nix           # Host-specific server secrets
├── network.nix          # Host-specific network secrets
└── shared.nix           # Framework for additional shared secrets
```

## How Shared Secrets Work

1. **shared.yaml** contains secrets all hosts need:
   - User passwords (for login)
   - Mail relay credentials (msmtp)
   - Any other cross-host secrets

2. **Category modules** reference shared.yaml:
   ```nix
   sops.secrets."passwords/${config.hostSpec.username}" = {
     sopsFile = "${sopsFolder}/shared.yaml";
     neededForUsers = true;
   };
   ```

3. **Bootstrap adds hosts** to shared.yaml rules:
   - `sops_add_shared_creation_rules` in helpers.sh
   - New hosts can immediately decrypt shared secrets

## Adding New Shared Secrets

1. Add secret to `nix-secrets/sops/shared.yaml`
2. Reference in appropriate category module:
   ```nix
   sops.secrets."my-shared-secret" = {
     sopsFile = "${sopsFolder}/shared.yaml";
   };
   ```
3. Rekey: `just rekey`
4. Update flake: `nix flake update nix-secrets`

## Secret Access by Role

| Role | shared.yaml | host.yaml |
|------|-------------|-----------|
| All roles | passwords/* | keys/age |
| Desktop/Laptop | ✓ | env_hass_*, network secrets |
| Server | ✓ | borg creds, service secrets |
| VM | ✓ | (base only) |

## Next Steps

Phase 4 complete! All secrets and security plans implemented:
- ✓ 04-01: SOPS audit and hasSecrets option
- ✓ 04-02: Role-based secret categories
- ✓ 04-03: Bootstrap and verification
- ✓ 04-04: Shared secrets integration

Ready for Phase 5: Reference Host (malphas migration)
