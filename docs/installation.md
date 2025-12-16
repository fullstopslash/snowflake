# Installation Guide

[README](../README.md) > Installation Guide

This guide covers installing NixOS hosts using the declarative host system.

## Installation Methods

### Remote Install (from another machine)

The fastest method - run from your workstation to install a target machine:

```bash
just install <hostname> <ip-address>
```

This uses nixos-anywhere to:
1. Partition and format disks with disko
2. Install NixOS configuration
3. Bootstrap secrets
4. Reboot into new system

### ISO Install (from recovery ISO)

For machines without network access or when you need local installation:

1. Build the ISO:
   ```bash
   nix build .#nixosConfigurations.iso.config.system.build.isoImage
   ```

2. Flash to USB and boot from it

3. The ISO will be discoverable as `mitosis.local` on the network

4. Connect to network if needed (NetworkManager is pre-configured)

5. Run the install command:
   ```bash
   install-host <hostname>
   ```

6. After reboot, bootstrap secrets:
   ```bash
   cd /path/to/nix-config
   ./scripts/bootstrap-secrets.sh <hostname>
   ```

The ISO includes:
- Embedded nix-config at `/etc/nix-config` for offline installation
- `install-host` command for easy installation
- Troubleshooting tools (neovim, btrfs-progs, bcachefs-tools, git, just)
- Pre-populated bash history with common commands
- Avahi/mDNS for network discovery

## Adding a New Host

The three-tier system makes adding hosts simple and declarative:

### 1. Create host directory and configuration

```bash
mkdir -p hosts/<hostname>
```

Create `hosts/<hostname>/default.nix`:

```nix
{
  imports = [
    ./hardware-configuration.nix
  ];

  # Select roles (form factor + task roles)
  roles = [
    "laptop"        # or "desktop", "server", "vm"
    "workstation"   # optional task role
  ];

  # Host identity and preferences
  host = {
    hostName = "<hostname>";
    # Override role defaults if needed:
    # wifi = true;
    # scaling = "1.5";
    # theme = "nord";
  };

  # Disk configuration for disko (installer)
  disks = {
    main = "/dev/nvme0n1";  # adjust for your hardware
  };
}
```

Create `hosts/<hostname>/hardware-configuration.nix`:
- Use `nixos-generate-config` on the target machine
- Or copy from similar hardware and adjust

### 2. Select modules (optional)

Roles provide sensible defaults, but you can customize:

```nix
{
  # Add to role's defaults
  modules.desktop = [ "hyprland" ];
  modules.development = [ "nix" "rust" ];

  # Or completely override (use with caution)
  modules.desktop = lib.mkForce [ "gnome" ];
}
```

### 3. Install

No manual flake edits needed - host auto-discovery handles it!

Use either installation method above:
- `just install <hostname> <ip>` (remote)
- `install-host <hostname>` (from ISO)

## Architecture Notes

The system uses a three-tier architecture:

### /roles (Presets)
- Form factors: desktop, laptop, tablet, server, vm, pi
- Task roles: workstation, development, media
- Set defaults for architecture, wifi, modules, secrets
- Provide sensible starting points

### /modules (Units)
- Individual pieces of functionality
- Services, apps, development tools
- Enabled/disabled via `modules.*` selections
- Composed by roles or hosts

### /hosts (Identity)
- What makes each machine unique
- Hardware specifics (wifi, HDR, scaling)
- User preferences (theme, browser, wallpaper)
- Override role defaults as needed

## Host Behavior

Host behavior is **declarative** - defined in host configs:

```nix
# WHO the machine is (identity)
host.hostName = "griefling";
host.primaryUsername = "rain";

# WHAT it has (hardware)
host.wifi = true;
host.hdr = false;
host.scaling = "1.5";

# WHAT it does (preferences)
host.theme = "dracula";
host.defaultBrowser = "firefox";

# HOW it behaves (derived from modules/roles)
# These are computed automatically:
# host.useWayland = true;  (if wayland desktop selected)
# host.isDevelopment = true;  (if dev modules selected)
# host.isHeadless = false;  (set by vm-headless role)
```

No centralized lists - the flake discovers hosts automatically from the `hosts/` directory.

## Verification

After installation, verify the system:

```bash
# Check secrets are working
./scripts/check-sops.sh --verbose

# Verify system info
hostnamectl

# Check role configuration
nixos-option host
```

## Troubleshooting

### "SOPS: Host secrets file not found"

The host's secrets file doesn't exist. Either:
- Run bootstrap-secrets.sh to create it
- Set `host.hasSecrets = lib.mkForce false` if no secrets needed

### "Failed to decrypt"

The host's age key isn't registered. Fix with:
1. `cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age`
2. Add key to nix-secrets/.sops.yaml
3. `just rekey` in nix-secrets
4. `nix flake update nix-secrets` in nix-config

### Build errors about missing options

Make sure you're importing the hardware-configuration.nix and that all required host options are set (hostName, primaryUsername).

## Further Reading

- [Adding a New Host](addnewhost.md) - Detailed bootstrap procedures
- [Migration Guide](migration-guide.md) - Updating existing hosts to new system
- [Recovery Procedures](recovery-procedures.md) - Disaster recovery

---

[Return to top](#installation-guide)

[README](../README.md) > Installation Guide
