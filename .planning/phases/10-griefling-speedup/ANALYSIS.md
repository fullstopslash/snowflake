# Griefling Deployment Analysis

## Current State: 300+ Packages in System-Path

### Package Elimination Tree

```
griefling (roles.vm = true, roles.test = true)
│
├── [WANTED] Core VM (~30 packages)
│   ├── systemd, glibc, coreutils, bash
│   ├── linux kernel + modules
│   ├── boot loader (systemd-boot)
│   ├── virtio drivers
│   ├── qemuGuest
│   └── networking (networkmanager)
│
├── [WANTED] Desktop GUI (~20 packages)
│   ├── Ly display manager
│   ├── Hyprland compositor
│   ├── waybar (status bar)
│   └── mesa (graphics)
│
├── [WANTED] Test Role Apps (~15 packages)
│   ├── Firefox
│   ├── Atuin
│   ├── Syncthing
│   ├── Tailscale
│   ├── git, curl, htop
│   └── sops/age for secrets
│
├── [ELIMINATE] KDE Plasma 6 (~39 packages)
│   │   Source: modules/services/desktop/plasma.nix (NO enable guard)
│   │   Import chain: roles/default.nix → hw-desktop.nix → modules/services/desktop → plasma.nix
│   │
│   ├── plasma-desktop-6.5.3
│   ├── plasma-workspace-6.5.3
│   ├── kwin-6.5.3, kwin-x11-6.5.3
│   ├── dolphin-25.08.3, dolphin-plugins
│   ├── konsole-25.08.3
│   ├── kate-25.08.3
│   ├── gwenview-25.08.3
│   ├── elisa-25.08.3
│   ├── discover-6.5.3
│   ├── konqueror-25.08.3
│   ├── kdeconnect-kde-25.08.3
│   ├── kdeplasma-addons-6.5.3
│   ├── polkit-kde-agent-1-6.5.3
│   ├── xdg-desktop-portal-kde-6.5.3
│   └── ... (25+ more KDE packages)
│
├── [ELIMINATE] Media Stack (~15 packages)
│   │   Source: modules/apps/media/default.nix (NO enable guard)
│   │   Import chain: roles/default.nix → hw-desktop.nix → modules/apps/media
│   │
│   ├── jellyfin-10.11.3
│   ├── jellyfin-web-10.11.3
│   ├── jellyfin-ffmpeg-7.1.2-2
│   ├── jellyfin-mpv-shim-2.9.0
│   ├── jellyfin-tui-1.2.6
│   ├── jftui-0.7.5
│   ├── jellycli-0.9.1
│   ├── spotify-1.2.59
│   ├── vlc-3.0.21
│   ├── mpd-0.24.6, mpv
│   ├── easyeffects-8.0.4
│   └── ffmpeg-full-8.0
│
├── [ELIMINATE] Development Tools (~10 packages)
│   │   Source: modules/services/development/quickemu.nix, etc.
│   │
│   ├── quickemu-4.9.7
│   ├── aider-chat-0.86.1
│   ├── aichat-0.30.0
│   └── various dev dependencies
│
├── [ELIMINATE] Heavy CLI Tools (~20 packages)
│   │   Source: modules/apps/cli/tools.nix (has enable but not used correctly)
│   │
│   ├── wezterm
│   ├── nodejs
│   ├── chezmoi
│   └── many TUI/CLI tools
│
└── [ELIMINATE] Other Bloat (~20 packages)
    ├── niri-25.08 (another compositor)
    ├── bitwarden-desktop
    ├── flatpak
    └── various utilities

```

## Root Cause Diagram

```
flake.nix
    │
    ▼ imports ./roles for ALL hosts
roles/default.nix
    │
    ├── imports ./hw-desktop.nix (unconditionally)
    ├── imports ./hw-laptop.nix  (unconditionally)
    ├── imports ./hw-vm.nix      (unconditionally)
    └── ...
    │
    ▼ hw-desktop.nix has imports OUTSIDE mkIf block
    │
    imports = [
        ../modules/services/desktop    ─┐
        ../modules/apps/media           │
        ../modules/apps/gaming          │ ALL EVALUATED
        ../modules/apps/development     │ REGARDLESS OF
        ...                            ─┘ roles.desktop value
    ]
    │
    ▼ modules/services/desktop/default.nix
    │
    imports = lib.custom.scanPaths ./. (loads ALL .nix files)
    │
    ├── plasma.nix (NO enable guard → unconditional Plasma 6)
    ├── niri.nix
    ├── hyprland.nix (has enable guard ✓)
    └── ...
```

## Solution: Enable-Gated Pattern

**Before (BROKEN):**
```nix
# roles/hw-desktop.nix
{
  imports = [
    ../modules/services/desktop   # ← EVALUATED FOR ALL HOSTS
  ];

  config = lib.mkIf cfg.desktop {
    # Desktop-specific config
  };
}

# modules/services/desktop/plasma.nix
{
  services.desktopManager.plasma6.enable = true;  # ← NO GUARD!
}
```

**After (FIXED):**
```nix
# roles/hw-desktop.nix
{
  # NO imports at top level

  config = lib.mkIf cfg.desktop {
    myModules.desktop.plasma.enable = lib.mkDefault true;
    myModules.apps.media.enable = lib.mkDefault true;
  };
}

# modules/services/desktop/plasma.nix
let cfg = config.myModules.desktop.plasma; in {
  options.myModules.desktop.plasma.enable = lib.mkEnableOption "Plasma 6";

  config = lib.mkIf cfg.enable {
    services.desktopManager.plasma6.enable = true;
  };
}
```

## Expected Results After Fix

| Metric | Before | After |
|--------|--------|-------|
| System-path derivations | 300+ | <100 |
| KDE/Plasma packages | 39 | 0 |
| Jellyfin packages | 5 | 0 |
| Media players (Spotify, VLC) | 3+ | 0 |
| Evaluation time | Slow | Fast |
| Build closure size | ~5GB+ | <1GB |

## Modules Requiring Enable Guards

### Critical (causing major bloat):
- [x] modules/apps/gaming/default.nix ← Already has enable
- [ ] modules/services/desktop/plasma.nix ← NEEDS FIX
- [ ] modules/apps/media/default.nix ← NEEDS FIX

### Important (moderate bloat):
- [x] modules/apps/development/latex.nix ← Already has enable
- [x] modules/services/development/containers.nix ← Already has enable
- [x] modules/apps/cli/tools.nix ← Already has enable
- [x] modules/apps/cli/shell.nix ← Already has enable

### Should verify:
- modules/services/ai/ollama.nix
- modules/services/ai/crush.nix
- modules/services/misc/flatpak.nix
- modules/services/misc/voice-assistant.nix
- modules/services/audio/pipewire.nix
- modules/services/storage/borg.nix
- modules/services/storage/network-storage.nix

## New Module Recommendations

### 1. roles/task-fast-test.nix
Explicitly disables heavy modules for fast deployment testing:
```nix
config = lib.mkIf cfg.fastTest {
  myModules = {
    desktop.plasma.enable = lib.mkForce false;
    apps.media.enable = lib.mkForce false;
    apps.gaming.enable = lib.mkForce false;
    services.development.containers.enable = lib.mkForce false;
  };
};
```

### 2. Consider: roles/task-minimal-gui.nix
For VMs that need GUI but minimal packages:
- Ly or greetd (no SDDM)
- Hyprland only (no Plasma, no niri)
- Firefox only (no heavy apps)
- Basic theming

### 3. Consider: Splitting media module
Current `modules/apps/media/default.nix` is monolithic. Consider:
- modules/apps/media/jellyfin.nix
- modules/apps/media/spotify.nix
- modules/apps/media/vlc.nix
- modules/apps/media/mpd.nix

This allows finer-grained control (e.g., VLC without Jellyfin).
