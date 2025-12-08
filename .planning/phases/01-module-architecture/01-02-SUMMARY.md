# Phase 1 Plan 2: Module Directory Restructure Summary

**Created three-tier module structure for auto-applied and subscribable roles**

## Accomplishments
- Created `modules/common/` directory for auto-applied modules
- Created `modules/opt-in/` directory for subscribable role registry
- Moved `roles/universal.nix` to `modules/common/universal.nix`
- Created `modules/common/default.nix` that imports universal.nix
- Created `modules/opt-in/default.nix` that exports all 39 available roles as an attrset
- Updated host configurations (malphas, vmtest) to reference new universal.nix path

## Files Created/Modified
**Created:**
- `modules/common/default.nix` - Auto-imports common modules (currently just universal.nix)
- `modules/opt-in/default.nix` - Registry exporting paths to all 39 opt-in roles

**Moved:**
- `roles/universal.nix` → `modules/common/universal.nix`

**Modified:**
- `hosts/malphas/default.nix` - Updated universal.nix import path
- `hosts/vmtest/default.nix` - Updated universal.nix import path

## Directory Structure
```
modules/
├── host-spec.nix          # (from 01-01)
├── common/                 # Auto-applied to ALL hosts
│   ├── default.nix        # Imports all common modules
│   └── universal.nix      # Core system settings (moved from roles/)
├── opt-in/                 # Hosts must explicitly import
│   └── default.nix        # Exports all opt-in role paths
└── (other modules: sops.nix, ssh-no-sleep.nix, etc.)

roles/                      # Still contains 39 opt-in role modules
├── ai-tools.nix
├── desktop.nix
├── hyprland.nix
... (36 more roles)
```

## Opt-in Registry Contents
The `modules/opt-in/default.nix` now exports 39 roles organized by category:
- **AI and Development Tools**: ai-tools, development, neovim
- **Desktop Environments**: desktop, hyprland, plasma, niri, greetd, flatpak, waybar
- **Gaming and Media**: gaming, media, obs, audio-tuning
- **Networking**: networking, tailscale, vpn, sinkzone, network-storage, syncthing
- **System Tools**: containers, quickemu, ollama
- **CLI and Shell**: cli-tools, shell, atuin
- **Utilities**: bitwarden-automation, document-processing, secrets, fonts, stylix
- **Specialized**: rust-packages, latex, crush, moondeck-buddy, voice-assistant

## Decisions Made
- Only universal.nix moved to common tier (all other roles remain opt-in)
- Roles remain in `roles/` directory for now - only the registry was created
- Used relative paths from modules/opt-in/ to roles/ (../../roles/*.nix)
- Organized opt-in registry with comments grouping related roles

## Verification Results
- `nix flake check` passed successfully
- Both host configurations (malphas, vmtest) evaluate correctly
- Module directory structure established
- All role paths in opt-in registry are valid

## Next Step
Ready for 01-03-PLAN.md (Malphas Migration & Validation) which will:
- Update flake.nix to auto-import modules/common/
- Update malphas to use opt-in registry
- Test live rebuild on malphas host
