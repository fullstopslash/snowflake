# Phase 13: Filesystem-Driven Module Selection

## Problem

Current `modules/selection.nix` uses manually maintained lists that don't reflect the actual filesystem structure. This creates:
- Maintenance burden (add module file, also update enum)
- Disconnect between filesystem and config
- Unclear where to edit/add modules

## Goal

Selection paths directly mirror filesystem:
```nix
# Config mirrors /modules/ structure
modules.services.desktop = [ "hyprland" "wayland" ];  # -> modules/services/desktop/{hyprland,wayland}.nix
modules.services.display-manager = [ "ly" ];          # -> modules/services/display-manager/ly.nix
modules.apps.cli = [ "shell" "tools" ];               # -> modules/apps/cli/{shell,tools}.nix
```

## Current Filesystem Structure

```
modules/
├── apps/
│   ├── ai/          (crush.nix, voice-assistant.nix, ai-tools.nix)
│   ├── browsers/    (default.nix)
│   ├── cli/         (shell.nix, tools.nix, zellij.nix)
│   ├── comms/       (default.nix)
│   ├── desktop/     (creative.nix)
│   ├── development/ (latex.nix, document-processing.nix, tools.nix, rust.nix, neovim.nix)
│   ├── editors/     (default.nix)
│   ├── gaming/      (default.nix, moondeck.nix)
│   ├── media/       (default.nix, obs.nix)
│   ├── productivity/(default.nix)
│   └── security/    (secrets.nix)
├── services/
│   ├── ai/          (ollama.nix)
│   ├── audio/       (pipewire.nix, easyeffects.nix, tools.nix)
│   ├── cli/         (atuin.nix)
│   ├── desktop/     (hyprland.nix, niri.nix, plasma.nix, wayland.nix, common.nix, waybar.nix)
│   ├── development/ (containers.nix, quickemu.nix)
│   ├── display-manager/ (ly.nix, greetd.nix)
│   ├── networking/  (tailscale.nix, openssh.nix, ssh.nix, syncthing.nix, vpn.nix...)
│   ├── security/    (bitwarden.nix, clamav.nix, yubikey.nix)
│   └── storage/     (borg.nix, network-storage.nix)
├── common/          (NOT selectable - always loaded)
├── disks/           (NOT selectable - separate disko system)
├── hardware/        (Needs review - maybe selectable)
├── theming/         (Needs review)
└── users/           (NOT selectable - always loaded)
```

## Design

### 1. Lib Helper: `lib.custom.scanSelectableModules`

```nix
# In lib/default.nix
# Scans a directory and returns module names (without .nix, excluding default.nix)
scanModuleNames = path:
  builtins.filter (f: f != "default") (
    builtins.map (f: lib.strings.removeSuffix ".nix" f) (
      builtins.filter (f: lib.hasSuffix ".nix" f && f != "default.nix") (
        builtins.attrNames (builtins.readDir path)
      )
    )
  );

# Scans subdirectories of a path
scanSubdirs = path:
  builtins.filter (f: (builtins.readDir path).${f} == "directory") (
    builtins.attrNames (builtins.readDir path)
  );
```

### 2. New Selection System

```nix
# modules/selection.nix
{ config, lib, ... }:
let
  modulesPath = ./.;  # /modules

  # Auto-discover selectable categories
  appsPath = modulesPath + "/apps";
  servicesPath = modulesPath + "/services";

  appsCategories = lib.custom.scanSubdirs appsPath;      # [ "ai" "cli" "gaming" ... ]
  servicesCategories = lib.custom.scanSubdirs servicesPath; # [ "audio" "desktop" ... ]

  # For each category, get available modules
  getModulesForCategory = basePath: category:
    lib.custom.scanModuleNames (basePath + "/${category}");

  # Generate options dynamically
  mkCategoryOption = basePath: category:
    let modules = getModulesForCategory basePath category;
    in lib.mkOption {
      type = lib.types.listOf (lib.types.enum modules);
      default = [];
      description = "Modules from ${category}/ to enable";
    };
in
{
  options.modules = {
    apps = lib.genAttrs appsCategories (mkCategoryOption appsPath);
    services = lib.genAttrs servicesCategories (mkCategoryOption servicesPath);
  };

  # Translation: modules.services.desktop = ["hyprland"] -> import module
}
```

### 3. Module Structure Requirements

Each selectable module must:
1. Have `options.myModules.<path>.enable = lib.mkEnableOption "...";`
2. Wrap config in `lib.mkIf cfg.enable { ... };`
3. The option path matches filesystem: `modules/services/desktop/hyprland.nix` -> `myModules.services.desktop.hyprland.enable`

### 4. Role Usage

```nix
# roles/form-desktop.nix
modules = {
  services = {
    desktop = [ "plasma" "hyprland" "wayland" "common" ];
    display-manager = [ "ly" ];
    audio = [ "pipewire" ];
  };
  apps = {
    cli = [ "shell" "tools" ];
    gaming = [ "default" ];
    media = [ "default" ];
  };
};
```

### 5. Host Usage

```nix
# hosts/myhost/default.nix
roles = [ "desktop" ];

# Add extra modules
extraModules.services.networking = [ "tailscale" ];
extraModules.apps.development = [ "rust" ];
```

## Implementation Steps

### Step 1: Create lib helpers
- Add `scanModuleNames` and `scanSubdirs` to `lib/default.nix`
- Test they correctly scan the filesystem

### Step 2: Audit module structure
- Ensure all selectable modules have proper enable options
- Option path must match filesystem path
- Document which modules are selectable vs always-loaded

### Step 3: Rewrite selection.nix
- Use lib helpers to auto-generate options
- Generate translation layer dynamically
- No more manual enum lists

### Step 4: Update roles
- Change from flat `modules.desktop` to nested `modules.services.desktop`
- Update all role files

### Step 5: Update hosts
- Update griefling, malphas, templates
- Verify builds work

### Step 6: Clean up
- Remove any manual module lists
- Update documentation

## Success Criteria

1. Adding a new module = just create the .nix file (no selection.nix updates)
2. Config paths exactly match filesystem paths
3. LSP autocompletion still works (via enum from filesystem scan)
4. Roles and hosts are minimal and clear
5. All existing hosts still build
