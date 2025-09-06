# NixOS Roles Documentation

This directory contains modular roles for NixOS configuration. Each role provides specific functionality and can be imported by hosts as needed.

## Role Structure

### Universal Role (`universal.nix`)
**Purpose**: Common settings and packages used across all hosts
**Contains**:
- System version and basic settings
- Common development tools (gcc, rustc, etc.)
- Common package managers (mise, uv, yarn, etc.)
- Common containers (distrobox, podman, etc.)
- Common system utilities (zenity, wget, etc.)
- Common Nix tools (cachix, etc.)

**Import**: Always import this role first in host configurations

### Desktop Role (`desktop.nix`)
**Purpose**: Desktop environment and GUI applications
**Contains**:
- Display manager (SDDM)
- Desktop environment (Plasma 6)
- Audio configuration (PipeWire)
- Desktop applications (browsers, media players, etc.)
- KDE utilities

**Dependencies**: `universal.nix`

### Development Role (`development.nix`)
**Purpose**: Development tools and programming environments
**Contains**:
- Language runtimes (Python, Java, Lua)
- Development tools (vim, neovim, etc.)
- Terminal tools (zellij, wezterm, etc.)
- Communication tools (discord, neomutt, etc.)

**Dependencies**: `universal.nix`

### Gaming Role (`gaming.nix`)
**Purpose**: Gaming applications and tools
**Contains**:
- Steam and gaming platforms
- Game development tools (Godot, SDL)
- Gaming utilities (Lutris, Bottles, etc.)
- Virtualization for gaming (Waydroid, Docker)

**Dependencies**: `universal.nix`

### Media Role (`media.nix`)
**Purpose**: Media servers and players
**Contains**:
- Jellyfin media server
- Media players (VLC, MPV)
- Audio/Video tools (VCV Rack, Cardinal)

**Dependencies**: `universal.nix`

### Networking Role (`networking.nix`)
**Purpose**: Network configuration and VPN
**Contains**:
- NetworkManager configuration
- Firewall settings
- VPN services (Mullvad, Tailscale)
- SSH and Avahi services

**Dependencies**: `universal.nix`

### Syncthing Role (`syncthing.nix`)
**Purpose**: File synchronization
**Contains**:
- Syncthing service configuration
- Device management
- Syncthing GUI tools

**Dependencies**: None

### Network Storage Role (`network-storage.nix`)
**Purpose**: NFS mounts and storage configuration
**Contains**:
- NFS client configuration
- Mount points for network storage
- RPC bind service

**Dependencies**: None

### LaTeX Role (`latex.nix`)
**Purpose**: Document processing and LaTeX
**Contains**:
- Tectonic LaTeX compiler
- TeXLive packages
- Document processing tools

**Dependencies**: None

### QuickEMU Role (`quickemu.nix`)
**Purpose**: Virtual machine management
**Contains**:
- QuickEMU package

**Dependencies**: None

### Secrets Role (`secrets.nix`)
**Purpose**: Secrets management
**Contains**:
- Age encryption tools
- SOPS configuration
- Password management tools

**Dependencies**: None

### Fonts Role (`fonts.nix`)
**Purpose**: Font configuration
**Contains**:
- Font packages and configuration

**Dependencies**: None

### Shell Role (`shell.nix`)
**Purpose**: Shell configuration
**Contains**:
- Shell programs (zsh, fish, nushell)
- Shell tools (fzf, atuin, zoxide, starship)
- Terminal emulators (ghostty, kitty, alacritty)

**Dependencies**: None

### Utilities Role (`utilities.nix`)
**Purpose**: System utilities
**Contains**:
- Email and password management
- Input remapping tools
- File management tools
- System utilities

**Dependencies**: None

### Document Processing Role (`document-processing.nix`)
**Purpose**: Document processing for wiki
**Contains**:
- Pandoc and document converters
- LaTeX packages for document processing
- Image processing tools
- PlantUML for diagrams

**Dependencies**: None

### Voice Assistant Role (`voice-assistant.nix`)
**Purpose**: Voice assistant functionality
**Contains**:
- Wyoming satellite and wake word services
- Voice assistant packages

**Dependencies**: None

### Cachix Role (`cachix.nix`)
**Purpose**: Binary cache configuration for faster builds
**Contains**:
- Popular Cachix cache substituters
- Trusted public keys for binary caches
- Cachix CLI tool

**Dependencies**: None

### Stylix Role (`stylix.nix`)
**Purpose**: Modular theming system using Stylix
**Contains**:
- Theme presets (Catppuccin, Dracula, Gruvbox, Nord, etc.)
- Font configuration (Noto fonts, JetBrains Mono)
- Cursor themes (Bibata cursors)
- Comprehensive theming for GTK, Qt, KDE, i3, Sway, etc.
- Custom base16 scheme support
- Wallpaper management

**Dependencies**: None
**Documentation**: See `stylix.md` for detailed usage instructions

## Best Practices

### Adding New Roles
1. Create a new `.nix` file in the `roles/` directory
2. Use the standard function signature: `{pkgs, ...}: { ... }`
3. Add role-specific packages to `environment.systemPackages`
4. Document the role's purpose and dependencies
5. Test with `nix flake check` before committing

### Package Organization
- **Common packages**: Put in `universal.nix`
- **Role-specific packages**: Put in the appropriate role
- **Avoid duplicates**: Check existing roles before adding packages
- **Group related packages**: Use comments to organize packages

### Importing Roles
```nix
# In hosts/<hostname>/default.nix
imports = [
  ../../roles/universal.nix    # Always first
  ../../roles/desktop.nix      # Desktop functionality
  ../../roles/development.nix  # Development tools
  # ... other roles as needed
];
```

### Testing Roles
```bash
# Test a specific host configuration
nix flake check

# Test individual role
nix eval .#nixosConfigurations.<hostname>.config.system.build.toplevel.drvPath

# Run quality checks
./scripts/quality-check.sh
```

## Maintenance

### Regular Tasks
1. Run `./scripts/quality-check.sh` before commits
2. Check for duplicate packages across roles
3. Update documentation when adding new roles
4. Test configurations after changes

### Common Issues
- **Duplicate packages**: Use `universal.nix` for common packages
- **Unused arguments**: Remove unused lambda arguments
- **Formatting issues**: Run `alejandra .` to fix formatting
- **Linting warnings**: Fix all `statix` and `deadnix` warnings 