# Summary 07-02: Convert Optional Configs to Modules

## Status: COMPLETE

## Changes Made

### Files Removed (23 unused optional files)
- hosts/common/optional/amdgpu_top.nix
- hosts/common/optional/audio.nix
- hosts/common/optional/fonts.nix
- hosts/common/optional/gaming.nix
- hosts/common/optional/libvirt.nix
- hosts/common/optional/msmtp.nix
- hosts/common/optional/nvtop.nix
- hosts/common/optional/obsidian.nix
- hosts/common/optional/plymouth.nix
- hosts/common/optional/protonvpn.nix
- hosts/common/optional/scanning.nix
- hosts/common/optional/smbclient.nix
- hosts/common/optional/stylix.nix
- hosts/common/optional/thunar.nix
- hosts/common/optional/vlc.nix
- hosts/common/optional/wifi.nix
- hosts/common/optional/xfce.nix
- hosts/common/optional/yubikey.nix
- hosts/common/optional/zsa-keeb.nix
- hosts/common/optional/services/bluetooth.nix
- hosts/common/optional/services/greetd.nix
- hosts/common/optional/services/printing.nix
- hosts/common/optional/services/sddm.nix

### New Modules Created (in modules/services/)
- networking/syncthing.nix - Syncthing with sops secrets integration
- networking/tailscale.nix - Tailscale VPN with OAuth key setup
- networking/openssh.nix - OpenSSH server configuration
- desktop/hyprland.nix - Hyprland compositor
- desktop/wayland.nix - Wayland session support
- desktop/ly.nix - Ly display manager
- misc/nix-config-repo.nix - Nix config repo setup

### Updated Optional Wrappers (now thin enablers)
- hosts/common/optional/syncthing.nix → `{ ... }: { myModules.services.syncthing.enable = true; }`
- hosts/common/optional/tailscale.nix → `{ ... }: { myModules.services.tailscale.enable = true; }`
- hosts/common/optional/hyprland.nix → `{ ... }: { myModules.desktop.hyprland.enable = true; }`
- hosts/common/optional/wayland.nix → `{ ... }: { myModules.desktop.wayland.enable = true; }`
- hosts/common/optional/services/ly.nix → `{ ... }: { myModules.desktop.ly.enable = true; }`
- hosts/common/optional/services/openssh.nix → `{ ... }: { myModules.networking.openssh.enable = true; }`
- hosts/common/optional/nix-config-repo.nix → `{ ... }: { myModules.services.nixConfigRepo.enable = true; }`

### Fixed Enable-Gating Issues
- modules/services/misc/voice-assistant.nix - Converted to enable-gated module, removed deprecated preloadModels option (removed in wyoming-openwakeword 2.0)
- modules/services/desktop/common.nix - Converted to enable-gated module to prevent sops template evaluation errors

## Module Pattern Used
```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.myModules.[category].[name];
in {
  options.myModules.[category].[name].enable = lib.mkEnableOption "description";
  config = lib.mkIf cfg.enable { /* original config */ };
}
```

## Verification
- Griefling builds successfully (dry-run passed)
- All modules follow consistent enable-gated pattern

## Commits
- f4be4f1 - refactor(07-02): remove unused optional configs and duplicate modules
- 1707d78 - refactor(07-02): convert optional configs to proper enable-gated modules
