# Summary: 08-02 Add Task-Based Roles

## Completed

### Task 1: Create roles/task-development.nix
Created task-based development role that composes with hardware roles:
- Sets `hostSpec.isDevelopment = lib.mkDefault true`
- Imports development modules from `modules/apps/development` and `modules/services/development`
- Uses `lib.mkIf cfg.development` pattern for conditional config

### Task 2: Create roles/task-mediacenter.nix
Created task-based media center role:
- Imports media modules from `modules/apps/media` and `modules/services/audio`
- Focuses on playback, not serving (server role handles that)

### Task 3: Update modules/common/roles.nix
Added task role options to the roles submodule:
- `development = lib.mkEnableOption "Development environment (IDEs, LSPs, dev tools)"`
- `mediacenter = lib.mkEnableOption "Media center role (media playback, streaming clients)"`
- Task roles are composable (not mutually exclusive like hardware roles)

### Task 4: Rename Files for Better Organization
Renamed all role files with prefixes for better grouping:
- Hardware roles: `hw-desktop.nix`, `hw-laptop.nix`, `hw-server.nix`, `hw-pi.nix`, `hw-tablet.nix`, `hw-darwin.nix`, `hw-vm.nix`
- Task roles: `task-development.nix`, `task-mediacenter.nix`
- Updated `roles/default.nix` imports to use new names

## Files Changed

### New Files
- `roles/task-development.nix`
- `roles/task-mediacenter.nix`

### Renamed Files
- `roles/darwin.nix` → `roles/hw-darwin.nix`
- `roles/desktop.nix` → `roles/hw-desktop.nix`
- `roles/laptop.nix` → `roles/hw-laptop.nix`
- `roles/pi.nix` → `roles/hw-pi.nix`
- `roles/server.nix` → `roles/hw-server.nix`
- `roles/tablet.nix` → `roles/hw-tablet.nix`
- `roles/vm.nix` → `roles/hw-vm.nix`

### Modified Files
- `modules/common/roles.nix` - Added task role options
- `roles/default.nix` - Updated imports with new file names

## Role Composition Pattern

Hardware roles are mutually exclusive:
```nix
roles.desktop = true;  # OR
roles.laptop = true;   # OR
roles.server = true;   # etc.
```

Task roles can compose with any hardware role:
```nix
roles.laptop = true;      # Hardware base
roles.development = true; # + dev tools
roles.mediacenter = true; # + media playback
```

## Verification

```bash
# All files parse correctly
nix-instantiate --parse roles/task-development.nix
nix-instantiate --parse roles/task-mediacenter.nix

# Build passes dry-run
nix build .#nixosConfigurations.griefling.config.system.build.toplevel --dry-run
```

## Future Task Roles

Potential additions identified:
- `gaming` - Game launchers, Steam, wine
- `homelab` - Self-hosted services management
- `creative` - Audio/video production tools
