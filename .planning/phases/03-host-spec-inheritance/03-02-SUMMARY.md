# Phase 3 Plan 2: Module Resolution Summary

**Roles now import desktop-relevant optional modules; host imports reduced by ~60%**

## Accomplishments

- Desktop role now imports 9 optional modules automatically
- Laptop role extends desktop with 2 laptop-specific optional modules
- Genoa host imports reduced from 17 to 7 (host-specific only)
- All hosts continue to evaluate correctly

## Modules Added to Desktop Role

| Module | Purpose |
|--------|---------|
| audio.nix | Pipewire, audio controls |
| fonts.nix | System fonts |
| gaming.nix | Steam, gaming packages |
| hyprland.nix | Hyprland compositor |
| wayland.nix | Wayland support |
| thunar.nix | File manager |
| vlc.nix | Media player |
| plymouth.nix | Boot splash |
| services/greetd.nix | Login manager |

## Modules Added to Laptop Role

Laptop includes all desktop modules plus:

| Module | Purpose |
|--------|---------|
| wifi.nix | Wireless networking |
| services/bluetooth.nix | Bluetooth support |

## Modules Kept Host-Specific

These require special handling or are truly host-specific:

| Module | Reason |
|--------|--------|
| stylix.nix | Requires inputs.stylix NixOS module import |
| openssh.nix | Server feature, not always wanted |
| printing.nix | Hardware-specific |
| nvtop.nix | GPU-specific monitoring |
| yubikey.nix | Hardware-specific |
| protonvpn.nix | User preference |
| obsidian.nix | User preference |
| libvirt.nix | Heavy dependency |

## Files Modified

- `roles/desktop.nix` - Added 9 optional module imports
- `roles/laptop.nix` - Added 11 optional module imports (9 desktop + 2 laptop)
- `hosts/nixos/genoa/default.nix` - Reduced imports from 17 to 7

## Verification Results

| Host | Evaluates | Inherits from Role |
|------|-----------|-------------------|
| roletest | Yes | roles.vm |
| malphas | Yes | (none, uses core) |
| genoa | Yes | roles.laptop |
| guppy | Yes | (none, uses core) |
| griefling | Yes | (none, uses core) |
| ghost | Yes | (none, uses core) |

| genoa Feature | Inherited | Source |
|---------------|-----------|--------|
| pipewire (audio) | Yes | laptop role |
| hyprland | Yes | laptop role |
| thunar | Yes | laptop role |
| steam (gaming) | Yes | laptop role |
| greetd | Yes | laptop role |
| bluetooth | Yes | laptop role |

## Design Decision: stylix.nix

The stylix.nix module was NOT added to roles because it requires `inputs.stylix.nixosModules.stylix` to be imported first. Hosts that want stylix must:
1. Import `inputs.stylix.nixosModules.stylix` in their imports
2. Import `hosts/common/optional/stylix.nix` for configuration

This is documented in the role files with a comment.

## Next Step

Proceed to Plan 03-03: Minimal host pattern (create test host demonstrating full inheritance)
