# Summary 07-03: Rename /home/ to /home-manager/

## Status: COMPLETE

## Changes Made

### Directory Restructure
- Renamed `home/` → `home-manager/`
- Moved `home/rain/` → `home-manager/users/rain/`

### Updated Path References
- hosts/common/users/default.nix:
  - `home/${user}/${hostSpec.hostName}.nix` → `home-manager/users/${user}/${hostSpec.hostName}.nix`
  - `home/${user}/common` → `home-manager/users/${user}/common`
  - `home/common/core/zsh/p10k` → `home-manager/common/core/zsh/p10k`

- home-manager/users/rain/griefling.nix:
  - `home/common/core` → `home-manager/common/core`
  - `home/rain/common/nixos.nix` → `home-manager/users/rain/common/nixos.nix`
  - `home/common/optional/${f}` → `home-manager/common/optional/${f}`

- home-manager/users/rain/iso.nix:
  - `home/common/core` → `home-manager/common/core`

### Deadnix Fixes (in moved files)
- chezmoi.nix - removed unused `lib` import
- rain-custom.nix - removed unused `config` import

## New Structure
```
home-manager/
├── common/
│   ├── core/              # Essential HM configs (nixvim, zsh, etc.)
│   │   ├── nixvim/
│   │   ├── zsh/
│   │   └── ...
│   └── optional/          # Optional HM configs (hyprland, browsers, etc.)
│       ├── desktops/
│       ├── browsers/
│       └── ...
└── users/
    └── rain/              # Per-user HM configs
        ├── griefling.nix
        ├── iso.nix
        └── common/
```

## Verification
- Griefling builds successfully (dry-run passed)
- All path references updated

## Commits
- d9f0d76 - refactor(07-03): rename home/ to home-manager/
