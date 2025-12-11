# 07-04 Home-Manager Config Audit

## Summary

After thorough analysis, **most HM configs must stay** because they use HM-specific features with no NixOS equivalent. The primary migration opportunity is **package lists**.

## Categories

### MUST_STAY_HM (Requires Home-Manager)

These use HM-specific modules/features with no NixOS equivalent:

| File | Reason |
|------|--------|
| `core/zsh/default.nix` | `programs.zsh` with plugins, oh-my-zsh, dotDir, shell integrations |
| `core/zsh/aliases.nix` | Used by programs.zsh |
| `core/git.nix` | `programs.git` with user-specific ignores, delta, signing |
| `core/ssh.nix` | `programs.ssh` with complex matchBlocks, user key management |
| `core/ghostty.nix` | `programs.ghostty` with user keybinds |
| `core/kitty.nix` | `programs.kitty` with user settings |
| `core/bat.nix` | `programs.bat` with user config |
| `core/btop.nix` | `programs.btop` with user settings |
| `core/direnv.nix` | `programs.direnv` with shell integrations |
| `core/screen.nix` | User screen config |
| `core/nixvim/*` | Uses HM nixvim module (no NixOS equivalent) |
| `core/timers/trash-empty.nix` | `systemd.user.timers` (user systemd unit) |
| `core/default.nix` | `home.username`, `home.homeDirectory`, `xdg.userDirs`, `home.sessionPath` |
| `core/nixos.nix` | `home.activation`, `services.ssh-agent.enable` |
| `optional/browsers/firefox.nix` | `programs.firefox` with profiles, policies, userChrome |
| `optional/browsers/brave.nix` | User browser config |
| `optional/browsers/chromium.nix` | User browser config |
| `optional/desktops/hyprland/*` | `wayland.windowManager.hyprland` (HM-specific) |
| `optional/desktops/waybar.nix` | `programs.waybar` with systemd, user services |
| `optional/desktops/rofi.nix` | `programs.rofi` with user config |
| `optional/desktops/services/dunst.nix` | `services.dunst` (HM user service) |
| `optional/desktops/gtk.nix` | `gtk.*` options for per-user theming |
| `optional/desktops/playerctl.nix` | `services.playerctld` (HM user service) |
| `optional/development/default.nix` | `programs.git` extensions, `home.file` for git configs |
| `optional/sops.nix` | User-level sops config |
| `optional/chezmoi.nix` | `home.activation` script |
| `optional/xdg.nix` | User XDG mime associations |
| `optional/atuin.nix` | `programs.atuin` with shell integrations |
| `optional/zellij/*` | `programs.zellij` with user keybinds |
| `optional/comms/default.nix` | User communication apps |
| `optional/helper-scripts/default.nix` | User scripts |
| `optional/networking/protonvpn.nix` | User VPN config |
| `users/rain/common/*` | User-specific imports |
| `users/rain/griefling.nix` | Host-specific user config |
| `users/rain/iso.nix` | ISO user config |

### CAN_MIGRATE (Move to NixOS)

**Package Lists Only** - These are pure package installations that can move to `environment.systemPackages` or `users.users.*.packages`:

| File | Packages | Migration Target |
|------|----------|------------------|
| `core/default.nix` | coreutils, curl, eza, dust, fd, jq, etc. | `environment.systemPackages` |
| `core/nixos.nix` | e2fsprogs, cntr, strace, copyq, etc. | `environment.systemPackages` |
| `optional/desktops/default.nix` | pulseaudio, pavucontrol, wl-clipboard, galculator | `environment.systemPackages` |
| `optional/gaming/default.nix` | path-of-building | `environment.systemPackages` |
| `optional/media/default.nix` | ffmpeg, spotify, vlc, calibre | `environment.systemPackages` |
| `optional/development/default.nix` | direnv, delta, act, gh, glab, nmap, etc. | `environment.systemPackages` |

### CAN_MIGRATE (Program Enables)

These programs have NixOS equivalents but lose shell integrations:

| HM Module | NixOS Equivalent | Notes |
|-----------|------------------|-------|
| `programs.direnv` | `programs.direnv.enable` | Loses bash/zsh integration (HM provides it) |

## Migration Risk Assessment

| Migration Type | Risk | Effort | Benefit |
|----------------|------|--------|---------|
| Package lists → systemPackages | Low | Low | Minimal - packages work same either way |
| Program enables → NixOS | Medium | Medium | Minimal - lose shell integrations |
| Shell configs | High | High | Not recommended - HM-specific |
| Desktop configs | High | High | Not recommended - HM-specific |

## Recommendation

**Phase B (Trivial)**:
- Consider migrating package lists, but this provides minimal benefit
- Packages in HM vs NixOS work identically for the user
- Migration adds complexity without meaningful gains

**Phase C (Complex)**:
- Skip - too much HM-specific functionality
- Would require rewriting configs entirely
- High risk of breaking functionality

**Phase D (Document)**:
- Document that HM is genuinely required for this config
- The remaining configs are not "unnecessary HM usage" - they use HM-specific features

## Why HM is Actually Needed

1. **User-specific configs**: Git signing keys, SSH match blocks, browser profiles
2. **Shell integrations**: zsh plugins, direnv, zoxide, nix-index all need HM
3. **User services**: dunst, waybar, ssh-agent, timers
4. **Desktop WM**: Hyprland config via `wayland.windowManager.hyprland`
5. **Activation scripts**: chezmoi init, font cache reload
6. **XDG management**: User directories, mime associations

## Conclusion

The current HM usage is **appropriate and minimal**. Most configs use HM-specific features that have no NixOS equivalent. The only true candidates for migration are package lists, which provides negligible benefit.

**Recommendation**: Mark 07-04 as complete with this audit documenting that the current HM usage is justified. No major migrations needed.
