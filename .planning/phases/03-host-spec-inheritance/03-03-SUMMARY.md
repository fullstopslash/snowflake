# Phase 3 Plan 3: Minimal Host Pattern Summary

**Minimal desktop host demonstrates full role inheritance in 40 lines**

## Accomplishments

- Created minimaltest host demonstrating the minimal pattern
- Verified full inheritance from desktop role
- Documented override pattern
- All hosts continue to evaluate

## Minimal Host Pattern

A new desktop host needs only:

```nix
{ lib, ... }:
{
  imports = [
    (lib.custom.relativeToRoot "hosts/common/core")
  ];

  # Just pick a role
  roles.desktop = true;

  # Required: who and what
  hostSpec = {
    hostName = "myhost";
    primaryUsername = "myuser";
  };

  # Required: hardware
  fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };
  boot.loader.grub.device = "/dev/sda";

  system.stateVersion = "25.05";
}
```

## Line Count Comparison

| Host | Lines | Description |
|------|-------|-------------|
| minimaltest | 40 | Minimal desktop, full inheritance |
| genoa | 117 | Laptop with host-specific quirks |
| ghost | 165 | Desktop with many custom features |

## Inheritance Verification

All of these come automatically from `roles.desktop = true`:

| Feature | Inherited | Value |
|---------|-----------|-------|
| hostSpec.useWayland | Yes | true |
| hostSpec.useWindowManager | Yes | true |
| hostSpec.isDevelopment | Yes | true |
| services.xserver.enable | Yes | true |
| hardware.graphics.enable | Yes | true |
| services.pipewire.enable | Yes | true |
| programs.hyprland.enable | Yes | true |
| programs.thunar.enable | Yes | true |
| programs.steam.enable | Yes | true |
| services.greetd.enable | Yes | true |

## Override Pattern

Hosts can override role defaults using `lib.mkForce`:

```nix
hostSpec = {
  hostName = "myhost";
  primaryUsername = "myuser";
  # Override role default:
  useWayland = lib.mkForce false;  # Use X11 instead
};
```

## Add a New Machine Workflow

1. Create `hosts/nixos/newhost/default.nix`
2. Copy the minimal pattern above
3. Set hostname, username
4. Add hardware-configuration.nix (from `nixos-generate-config`)
5. Choose role: `roles.desktop`, `roles.laptop`, `roles.server`, etc.
6. Add host-specific quirks if needed
7. `git add hosts/nixos/newhost/` (required for flake to see it)
8. `nh os switch` or `nixos-rebuild switch --flake .#newhost`

Estimated time: **under 10 minutes** for a basic host

## Files Created

- `hosts/nixos/minimaltest/default.nix` - Minimal desktop host (40 lines)

## Phase 3 Complete

All three plans executed successfully:
- 03-01: Clean hostSpec & add role defaults ✓
- 03-02: Module resolution ✓
- 03-03: Minimal host pattern ✓

**Next Step:** Phase 4 (Secrets & Security) or commit Phase 3 changes
