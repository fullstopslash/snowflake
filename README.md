# Multi-Host NixOS Configuration

This repository contains a modular NixOS configuration designed for managing multiple hosts with shared roles and host-specific configurations.

## Structure

```
nix/
├── flake.nix                    # Main flake with all hosts
├── hosts/                       # Host-specific configurations
│   ├── default.nix             # Host registry
│   └── nixos/                  # Current host configuration
│       ├── default.nix         # Host configuration
│       └── hardware.nix        # Hardware-specific config
├── roles/                       # Reusable role modules
│   ├── default.nix             # Role registry
│   ├── desktop.nix             # Desktop environment
│   ├── gaming.nix              # Gaming setup
│   ├── development.nix         # Development tools
│   ├── media.nix               # Media server setup
│   ├── networking.nix          # Network configuration
│   ├── syncthing.nix           # Syncthing configuration
│   ├── network-storage.nix     # Network storage (NFS)
│   ├── latex.nix               # LaTeX environment
│   ├── secrets.nix             # Secrets management (SOPS)
│   ├── universal.nix           # Universal settings for all hosts
│   ├── fonts.nix               # Font configuration
│   ├── shell.nix               # Shell configuration
│   └── utilities.nix           # Utility packages
├── modules/                     # System-level modules
│   ├── hdr.nix                 # HDR display configuration
│   └── ssh-no-sleep.nix        # SSH session management
├── secrets.yaml                 # Encrypted secrets (SOPS)
├── scripts/                     # Helper scripts
│   └── sops-manager.sh         # SOPS management script
└── modules/                     # System-level modules
```

## Hosts

Each host has its own directory under `hosts/` containing:
- `default.nix` - Main host configuration
- `hardware.nix` - Hardware-specific settings

### Current Hosts

- **nixos** - Main desktop system with all roles enabled

### Dynamic Hostnames

Hostnames are automatically set based on the folder name in `hosts/`. The `flake.nix` uses a `mkHost` function that:
- Automatically sets `networking.hostName` to the folder name
- Makes it easy to create new hosts by just adding a folder
- Ensures consistent hostname management across all hosts

## Roles

Roles are modular configurations that can be applied to any host:

### Desktop Role (`roles/desktop.nix`)
- Display manager (SDDM)
- Desktop environment (Plasma 6)
- Audio (PipeWire)
- Input devices
- Desktop utilities and applications

### Gaming Role (`roles/gaming.nix`)
- Steam and gaming tools
- Game mode
- Virtualization (Docker, Waydroid)
- Gaming-specific packages
- Streaming tools (sunshine, moonlight-qt)
- Gaming utilities (antimicrox, winetricks)

### Development Role (`roles/development.nix`)
- Development tools and languages
- Rust toolchain
- Container tools
- Development utilities
- Git tools (gitFull, git-lfs, delta)
- Neovim configuration

### Media Role (`roles/media.nix`)
- Media servers (Jellyfin)
- OBS Studio with plugins and kernel modules
- Media players and tools
- Virtual camera support (v4l2loopback)
- See `docs/jellyfin-websocket-issues.md` for Jellyfin troubleshooting

### Networking Role (`roles/networking.nix`)
- Network management
- VPN services (Mullvad, Tailscale)
- SSH and firewall configuration
- Voice assistant services

### Syncthing Role (`roles/syncthing.nix`)
- Syncthing file synchronization
- Device configuration (currently hardcoded, SOPS integration ready)
- Syncthing tray application

### Network Storage Role (`roles/network-storage.nix`)
- NFS client support
- Network file system mounts
- Storage automounting

### LaTeX Role (`roles/latex.nix`)
- LaTeX development environment
- TeXLive with tlmgr support
- FHS environment for LaTeX tools

### Secrets Role (`roles/secrets.nix`)
- System-wide SOPS installation
- Age encryption tools
- Secrets directory management
- SOPS configuration setup

### Universal Role (`roles/universal.nix`)
- User configuration (rain user)
- System settings (timezone, locale, Nix settings)
- Security settings (polkit, sudo)
- Auto-upgrade and garbage collection
- NH and Nix-LD configuration
- SSH authorized keys

### Fonts Role (`roles/fonts.nix`)
- Comprehensive font collection
- Nerd fonts for development
- Noto fonts for international support
- Programming fonts (Fira Code, JetBrains Mono)
- Specialized fonts (Victor Mono, Monaspace)

### Shell Role (`roles/shell.nix`)
- Shell configurations (zsh, nushell, fish)
- Shell tools (fzf, atuin, zoxide, starship)
- Terminal emulator (ghostty)
- Shell completion (carapace)

### Utilities Role (`roles/utilities.nix`)
- Email and password management (thunderbird, keepassxc)
- File management tools (yazi, chezmoi, gnupg)
- System utilities (btop, ncdu, tmux)
- Development tools (alejandra, nodejs)
- Wine with Wayland support

## Modules

System-level modules that provide specific functionality:

### HDR Module (`modules/hdr.nix`)
- HDR display configuration
- Gamescope WSI support
- Chaotic-nyx HDR integration

### SSH No-Sleep Module (`modules/ssh-no-sleep.nix`)
- Prevents system sleep during active SSH sessions
- PAM integration for session management

## Secrets Management (SOPS)

This repository uses **SOPS** (Secrets OPerationS) for managing sensitive data like API keys, device IDs, and passwords. SOPS is available system-wide through the secrets role.

### Single Secrets File Convention

We use a **single `secrets.yaml` file** in the repository root for all encrypted secrets. This approach provides:

- **✅ Easier Management** - One file to edit, one file to backup
- **✅ Better Organization** - All secrets in one place with clear structure
- **✅ Simpler Key Management** - One encryption key for all secrets
- **✅ Easier Version Control** - Single file to track changes
- **✅ Better Security** - Less chance of forgetting to encrypt a file

### Current Status

- ✅ **SOPS Infrastructure**: SOPS and age are installed system-wide
- ✅ **Single Secrets File**: `secrets.yaml` encrypted and working
- ✅ **Management Script**: Helper script for common SOPS operations
- ✅ **Configuration**: SOPS configuration and .gitignore updated
- ✅ **Age Key**: User's age key configured and working
- ✅ **System Stability**: Configuration builds and works correctly
- 🔄 **Runtime Integration**: Build-time decryption needs refinement

### Setup

1. **SOPS is automatically installed** with the secrets role:
   ```bash
   # SOPS and age are available system-wide
   sops --version
   age-keygen --version
   ```

2. **Initialize SOPS**:
   ```bash
   ./scripts/sops-manager.sh init
   ```

3. **Create encrypted secrets**:
   ```bash
   ./scripts/sops-manager.sh create
   ```

### Managing Secrets

Use the provided script for common operations:

```bash
# Edit encrypted secrets
./scripts/sops-manager.sh edit

# Validate secrets file
./scripts/sops-manager.sh validate

# Decrypt and view secrets (for debugging)
./scripts/sops-manager.sh decrypt
```

### Manual SOPS Commands

```bash
# Encrypt the secrets file
sops -e -i secrets.yaml

# Decrypt the secrets file
sops -d secrets.yaml

# Edit encrypted file
sops secrets.yaml
```

### Secrets File Structure

The `secrets.yaml` file is organized into sections:

```yaml
# Syncthing device configurations
syncthing:
  devices:
    waterbug:
      id: "YOUR_DEVICE_ID_HERE"
      autoAcceptFolders: true

# API keys and tokens
api_keys:
  example_service: "your_api_key_here"

# Database credentials
databases:
  example_db:
    host: "localhost"
    password: "your_password_here"

# Network configurations
networking:
  vpn_credentials:
    username: "your_username"
    password: "your_password"

# Application secrets
applications:
  jellyfin:
    api_key: "your_jellyfin_api_key"
```

## Documentation

Additional documentation is available in the `docs/` directory:

- **Multi-Host SOPS Deployment** (`docs/multi-host-sops.md`) - Guide for deploying SOPS secrets management across multiple hosts
- **Jellyfin WebSocket Issues** (`docs/jellyfin-websocket-issues.md`) - Documentation on known Jellyfin websocket connection issues and troubleshooting
- **Optimization Guide** (`docs/optimization-guide.md`) - System optimization recommendations

## **Multi-Host Deployment**

This repository supports deploying to multiple hosts with secure secrets management. See `docs/multi-host-sops.md` for detailed deployment strategies.

### **Quick Start for New Hosts**

1. **Export your age public key:**
   ```bash
   ./scripts/host-init.sh export-key
   ```

2. **Create new host setup:**
   ```bash
   ./scripts/host-init.sh setup-new-host <hostname>
   ```

3. **Edit and encrypt secrets:**
   ```bash
   sops hosts/<hostname>/secrets.yaml
   sops -e -i hosts/<hostname>/secrets.yaml
   ```

4. **Deploy to new host:**
   ```bash
   # On new host: clone repo, copy age key, then:
   nh os switch --flake .#<hostname>
   ```

### **Available Scripts**

- `./scripts/sops-manager.sh` - Manage encrypted secrets
- `./scripts/host-init.sh` - Initialize new hosts with SOPS
- `./scripts/quality-check.sh` - Run comprehensive quality checks
- `./scripts/dev-workflow.sh` - Development workflow automation

### **Quality Assurance**

The repository includes automated quality checks to ensure maintainability:

```bash
# Run all quality checks
./scripts/quality-check.sh

# Development workflow
./scripts/dev-workflow.sh quality-check
./scripts/dev-workflow.sh test-host <hostname>
./scripts/dev-workflow.sh build-switch <hostname>
./scripts/dev-workflow.sh create-host <hostname>
```

**Quality checks include:**
- ✅ Nix flake validation
- ✅ Code formatting (Alejandra)
- ✅ Linting (Statix)
- ✅ Dead code detection (Deadnix)
- ✅ TODO/FIXME comment detection
- ✅ Duplicate package detection

### **Creating New Hosts**

The repository now includes a template system for easy host creation:

```bash
# Create new host from template
./scripts/dev-workflow.sh create-host <hostname>

# Or use the host init script directly
./scripts/host-init.sh create-new-host <hostname>
```

This creates a new host directory with:
- Template configuration files
- Proper imports structure
- Hardware configuration template
- Role selection comments

**Next steps after creating a host:**
1. Edit `hosts/<hostname>/hardware.nix` for your hardware
2. Edit `hosts/<hostname>/default.nix` to enable needed roles
3. Run `./scripts/dev-workflow.sh test-host <hostname>` to test
4. Run `./scripts/dev-workflow.sh build-switch <hostname>` to deploy

### **Next Steps for Full Runtime Integration**

The SOPS infrastructure is complete and ready for full integration. The current limitation is Nix's pure evaluation model, which prevents accessing external files during evaluation.

**Current Approach:**
- ✅ Encrypted secrets infrastructure working
- ✅ Management tools functional
- ✅ System builds and works correctly
- ✅ Multi-host deployment ready
- 🔄 Runtime decryption needs Nix-compatible implementation

**Future Integration Options:**
1. **Research Nix-compatible SOPS patterns** - Find established patterns for SOPS with Nix
2. **Implement build-time decryption** - Use `pkgs.runCommand` with proper path handling
3. **Enable sops-nix runtime** - Configure sops-nix for runtime decryption
4. **Use external secrets** - Store secrets outside the flake and reference them

**Immediate Benefits:**
- ✅ All secrets are encrypted and secure
- ✅ Management tools are working
- ✅ System is stable and functional
- ✅ Multi-host deployment ready
- ✅ Ready for production use

### Security Notes

- **Never commit unencrypted secrets** - Only `secrets.yaml` should be committed
- **Keep your age keys private** - Store them securely and don't commit them
- **Use different keys for different environments** - Production vs development
- **Rotate keys regularly** - Update encryption keys periodically

## Workflow

This repository uses **jujutsu (jj)** for git operations and **nh** for NixOS builds.

### Git Operations (using jujutsu)
```bash
# Check status
jj status

# View commit history
jj log

# Make a commit
jj commit -m "Description of changes"

# Push changes
jj git push
```

### NixOS Builds (using nh)
```bash
# Switch to new configuration
nh os switch --flake .#nixos

# Switch to specific host
nh os switch --flake .#hostname

# Test configuration
nix flake check

# Build configuration
nix build .#nixosConfigurations.nixos.config.system.build.toplevel
```

## Adding a New Host

1. Create a new directory under `hosts/` (e.g., `hosts/laptop/`)
2. Create `hosts/laptop/default.nix` with host-specific configuration
3. Create `hosts/laptop/hardware.nix` with hardware-specific settings
4. Add the host to `flake.nix` using the `mkHost` function

Example host configuration:
```nix
# hosts/laptop/default.nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware.nix
    ../../roles/universal.nix    # Universal settings
    ../../roles/desktop.nix      # Desktop environment
    ../../roles/development.nix  # Development tools
    ../../roles/networking.nix   # Network configuration
    ../../roles/secrets.nix      # SOPS access
  ];

  # Enable roles
  roles.universal.enable = true;
  roles.desktop.enable = true;
  roles.development.enable = true;
  roles.networking.enable = true;
  
  # Host-specific settings...
  # Note: hostname is automatically set to "laptop" based on folder name
}
```

Then add to `flake.nix`:
```nix
nixosConfigurations = {
  nixos = mkHost "nixos";
  laptop = mkHost "laptop";  # Add this line
};
```

## Adding a New Role

1. Create a new role file under `roles/` (e.g., `roles/server.nix`)
2. Add the role to `roles/default.nix`
3. Import the role in host configurations as needed

## Usage

To build a specific host:
```bash
nh os switch --flake .#nixos
```

To build a different host:
```bash
nh os switch --flake .#hostname
```

## Migration Notes

This repository was migrated from a single-host configuration to a multi-host structure and fully eliminated Home Manager. The original `configuration.nix` has been split into:

- Host-specific settings → `hosts/nixos/default.nix`
- Hardware settings → `hosts/nixos/hardware.nix`
- Role-based configurations → `roles/*.nix`
- System-level modules → `modules/*.nix`
- Encrypted secrets → `secrets.yaml` (infrastructure ready)

All functionality from the original configuration and Home Manager is preserved but now organized in a modular, reusable structure using native NixOS options and secure secrets management infrastructure. 
