# Chat Context for NixOS Multi-Host Repository

## User Preferences
- **Git**: Use jujutsu (jj) instead of git commands
- **NixOS**: Use nh instead of nixos-rebuild
- **Shell**: zsh with oh-my-zsh
- **Editor**: Cursor with Nix language support

## Project Context
- Multi-host NixOS configuration with modular roles
- Hosts in `/hosts/` directory
- Roles in `/roles/` directory
- Uses flakes for configuration management
- Home Manager for user configuration

## Common Workflows
1. **Making changes**: Edit files → `jj add .` → `jj commit -m "message"` → `nh os switch --flake .#nixos`
2. **Adding new host**: Create host directory → Add to flake.nix → Test with `nix flake check`
3. **Adding new role**: Create role file → Add to roles/default.nix → Import in hosts

## Technical Details
- System: NixOS with flakes
- Kernel: linuxPackages_cachyos
- Desktop: Plasma 6 with SDDM
- Audio: PipeWire
- Network: NetworkManager with Tailscale/Mullvad VPN 