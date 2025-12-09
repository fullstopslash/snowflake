# Phase 4 Plan 1: Audit & Fix Current SOPS Setup - Summary

**All hosts now evaluate with sops-nix available; hasSecrets option controls actual secrets configuration**

## Accomplishments

1. **Moved sops-nix import to flake level**
   - sops-nix is now imported in `mkHost` for all hosts
   - Modules can freely reference sops options without checking if sops exists
   - Removed duplicate import from `hosts/common/core/default.nix`

2. **Added `hostSpec.hasSecrets` option**
   - Default: `true` - most hosts have secrets
   - Set to `false` for ISO (no secrets file exists)
   - Controls whether `hosts/common/core/sops.nix` configures secrets

3. **Made sops configuration conditional**
   - `hosts/common/core/sops.nix` wrapped in `lib.mkIf hasSecrets`
   - Hosts without secrets can still use roles that reference sops options

## Files Modified

| File | Change |
|------|--------|
| `flake.nix` | Added `inputs.sops-nix.nixosModules.sops` to mkHost modules |
| `hosts/common/core/default.nix` | Removed duplicate sops-nix import (now at flake level) |
| `hosts/common/core/sops.nix` | Wrapped in `lib.mkIf hasSecrets` |
| `modules/common/host-spec.nix` | Added `hasSecrets` option |
| `modules/services/security/sops.nix` | Simplified (sops always available) |
| `modules/services/security/bitwarden.nix` | Reverted to simpler form (sops always available) |
| `hosts/nixos/iso/default.nix` | Set `hasSecrets = false` |

## Verification Results

| Host | Evaluates | hasSecrets |
|------|-----------|------------|
| genoa | Yes | true |
| ghost | Yes | true |
| guppy | Yes | true |
| griefling | Yes | true |
| malphas | Yes | true |
| minimaltest | Yes | true |
| roletest | Yes | true |
| iso | Yes | false |

## Architecture

```
flake.nix
└── mkHost (all hosts)
    └── inputs.sops-nix.nixosModules.sops  # sops options always available
    └── ./roles                             # roles can reference sops options
    └── ./modules/common                    # modules can reference sops options
    └── hostPath                            # host config
        └── hosts/common/core/sops.nix      # actual secrets (if hasSecrets=true)
```

## Key Design Decisions

1. **sops-nix at flake level**: Makes sops options available to all modules without conditional checks
2. **hasSecrets guards actual configuration**: Not the option availability - cleaner code in modules
3. **ISO explicitly opts out**: `hasSecrets = false` instead of trying to detect

## Next Steps

Plan 04-02: Role-based secrets structure - create secret categories and role defaults
