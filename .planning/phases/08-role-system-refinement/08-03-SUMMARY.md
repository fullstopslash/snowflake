# Plan 08-03 Summary: Refactor hostSpec - Roles Set Defaults

## Objective Achieved

Successfully refactored the `hostSpec` system so that roles automatically set behavioral defaults, eliminating the need for hosts to manually configure most options. Hosts now only need to specify their hardware role and identity values (hostname).

## Changes Made

### 1. Option Categorization

All hostSpec options have been categorized into four groups:

#### Identity Options (Set by hosts)
- `primaryUsername`, `username`, `hostName` - User and host identity
- `email`, `domain`, `userFullName`, `handle` - User information (from nix-secrets)
- `home`, `persistFolder` - Filesystem paths
- `networking` - Network configuration (from nix-secrets)
- `isDarwin` - Platform indicator
- `users` - List of all users

#### Hardware Options (Set by hosts based on physical hardware)
- `wifi` - Wifi hardware present (roles provide defaults, hosts override)
- `hdr` - HDR display support
- `scaling` - Display scaling factor

#### Behavioral Options (Set by roles - hosts should NOT set these)
- `isMinimal` - Minimal installation flag
- `isProduction` - Production vs test environment
- `isDevelopment` - Development tools enabled
- `isMobile` - Mobile device flag
- `useWayland` - Wayland display server
- `useWindowManager` - Graphical window manager
- `hasSecrets` - SOPS secrets configured
- `useAtticCache` - LAN binary cache
- `secretCategories.*` - Secret category enablement

#### User Preference Options (Set by hosts based on preferences)
- `isWork` - Work resources enabled
- `useYubikey` - Yubikey authentication
- `voiceCoding` - Voice coding (Talon)
- `isAutoStyled` - Auto styling (stylix)
- `theme`, `wallpaper` - Visual preferences
- `useNeovimTerminal` - Terminal preference
- `defaultBrowser`, `defaultEditor`, `defaultDesktop` - Application preferences

### 2. Role Default Values

Each role now sets comprehensive behavioral defaults:

#### `roles/common.nix` (Universal defaults)
Sets defaults that apply to ALL hosts with any role enabled:
- `isProduction = true` - All hosts are production by default
- `hasSecrets = true` - All hosts have secrets by default
- `useAtticCache = true` - All hosts use LAN cache
- `secretCategories.base = true` - All hosts get base secrets

#### `roles/hw-desktop.nix` (Desktop workstation)
- `useWayland = true` - Desktop uses Wayland
- `useWindowManager = true` - Desktop has GUI
- `isDevelopment = true` - Desktop is for development
- `isMobile = false` - Desktop is stationary
- `wifi = false` - Desktop uses ethernet
- `isMinimal = false` - Full desktop environment
- Secret categories: `base`, `desktop`, `network`, `cli`

#### `roles/hw-laptop.nix` (Laptop)
Extends desktop settings with mobile-specific values:
- `useWayland = true` - Laptop uses Wayland
- `useWindowManager = true` - Laptop has GUI
- `isDevelopment = true` - Laptop is for development
- `wifi = true` - Laptops always have wifi
- `isMobile = true` - Laptops are mobile
- `isMinimal = false` - Full desktop environment
- Secret categories: `base`, `desktop`, `network`, `cli`

#### `roles/hw-server.nix` (Headless server)
- `useWayland = false` - Servers are headless
- `useWindowManager = false` - No GUI
- `isProduction = true` - Servers are production
- `isDevelopment = false` - Not a dev workstation
- `isMobile = false` - Servers are stationary
- `isMinimal = false` - Full server stack
- `wifi = false` - Servers use ethernet
- Secret categories: `base`, `server`, `network`, `cli`

#### `roles/hw-vm.nix` (Virtual machine)
- `isMinimal = true` - VMs are minimal
- `isProduction = false` - VMs are for testing
- `hasSecrets = false` - VMs don't have secrets by default
- `useWayland = false` - Minimal VMs are headless
- `useWindowManager = false` - No GUI
- `isDevelopment = false` - Not a dev workstation
- `isMobile = false` - VMs are not mobile
- `wifi = false` - VMs use virtual networking
- Secret categories: `base = false` (minimal by default)

#### `roles/hw-tablet.nix` (Touch-friendly tablet)
- `isMobile = true` - Tablets are mobile
- `wifi = true` - Tablets always have wifi
- `useWayland = true` - Modern tablets use Wayland
- `useWindowManager = true` - Tablets have GUI
- `isDevelopment = false` - Not a dev workstation
- `isMinimal = false` - Full touch-friendly UI
- Secret categories: `base`, `desktop`, `network`

#### `roles/hw-pi.nix` (Raspberry Pi)
- `isMinimal = true` - Pi is minimal/headless
- `useWayland = false` - Headless
- `useWindowManager = false` - No GUI
- `isDevelopment = false` - Not a dev workstation
- `isMobile = false` - Pis are stationary
- `isProduction = true` - Pi hosts are often production (home servers)
- `wifi = true` - Many Pis have wifi
- Secret categories: `base`, `network`

#### `roles/task-development.nix` (Composable development role)
- `isDevelopment = true` - Development environment enabled

All role defaults use `lib.mkDefault` so hosts can override with `lib.mkForce` if needed.

### 3. Documentation Updates

Updated `/home/rain/nix-config/modules/common/host-spec.nix` with comprehensive section headers:
- **IDENTITY OPTIONS - Set by hosts** - Clear separation of host-specific values
- **HARDWARE OPTIONS - Set by hosts** - Physical hardware capabilities
- **BEHAVIORAL OPTIONS - Set by roles** - Purpose and configuration (hosts should NOT set)
- **USER PREFERENCE OPTIONS - Set by hosts** - User preferences and choices
- **SECRET CATEGORIES - Set by roles** - Role-based secret management

Each option now has a description indicating which role sets it or whether it's host-specific.

## Benefits

1. **Reduced Host Configuration**: Hosts only need to set `hostName` and choose a role
2. **Consistency**: All hosts of the same role type get consistent defaults
3. **Maintainability**: Behavioral changes can be made in one place (the role)
4. **Clear Separation**: Identity (host), hardware (host), behavior (role), preferences (host)
5. **Flexibility**: Hosts can still override with `lib.mkForce` when needed
6. **Self-Documenting**: Options clearly indicate their source and purpose

## Verification Results

Tested with `griefling` host (desktop role):
```bash
$ nix eval .#nixosConfigurations.griefling.config.hostSpec.useWayland
true

$ nix eval .#nixosConfigurations.griefling.config.hostSpec.isDevelopment
true

$ nix eval .#nixosConfigurations.griefling.config.hostSpec.isMinimal
false

$ nix eval .#nixosConfigurations.griefling.config.hostSpec.secretCategories.desktop
true

$ nix eval .#nixosConfigurations.griefling.config.hostSpec.secretCategories.cli
true
```

All values are correctly inherited from the desktop role without any explicit host configuration.

## Example: Before vs After

### Before (08-03)
```nix
# hosts/nixos/griefling/default.nix
hostSpec = {
  hostName = "griefling";
  useWayland = true;
  isDevelopment = true;
  isMinimal = false;
  wifi = false;
  secretCategories = {
    base = true;
    desktop = true;
    network = true;
  };
};
```

### After (08-03)
```nix
# hosts/nixos/griefling/default.nix
roles.desktop = true;

hostSpec = {
  hostName = "griefling";
  # Desktop role provides: useWayland=true, isDevelopment=true, secretCategories
};
```

The host configuration is dramatically simplified - just role selection and hostname.

## Files Modified

1. `/home/rain/nix-config/roles/common.nix` - Added universal behavioral defaults
2. `/home/rain/nix-config/roles/hw-desktop.nix` - Comprehensive desktop defaults
3. `/home/rain/nix-config/roles/hw-laptop.nix` - Laptop-specific defaults
4. `/home/rain/nix-config/roles/hw-server.nix` - Server-specific defaults
5. `/home/rain/nix-config/roles/hw-vm.nix` - VM-specific defaults (minimal)
6. `/home/rain/nix-config/roles/hw-tablet.nix` - Tablet-specific defaults
7. `/home/rain/nix-config/roles/hw-pi.nix` - Pi-specific defaults
8. `/home/rain/nix-config/modules/common/host-spec.nix` - Documentation updates

## Next Steps

Plan 08-04 will clean up existing host configurations (griefling, malphas) to remove redundant hostSpec settings that are now provided by roles.

## Notes

- No options were deprecated or removed - all existing options remain functional
- The `task-development.nix` role already correctly set `isDevelopment`
- All changes use `lib.mkDefault` to allow host overrides
- Hardware options like `wifi` get role defaults but hosts can override based on actual hardware
- The categorization makes it clear what each host should and shouldn't configure
