# Hyprland Configuration

This directory contains the Home Manager Hyprland configuration.

## Structure

- `default.nix` - Base Hyprland configuration with common settings
- `binds.nix` - Key bindings (vim-like navigation, workspaces, etc)
- `scripts.nix` - Custom shell scripts (monitor toggling, tile arrangement)
- `hyprlock.nix` - Lock screen configuration
- `wlogout.nix` - Logout menu configuration
- `rain-custom.nix` - Custom configuration extracted from rain's imperative setup
- `user-scripts/` - Collection of custom bash scripts

## Usage

### Basic Setup

Import the hyprland module in your home-manager configuration:

```nix
imports = [
  desktops/hyprland
];
```

### With Custom Configuration

If you want to use the custom rain configuration (4K HDR, media window positioning, etc):

```nix
imports = [
  desktops/hyprland
  desktops/hyprland/rain-custom.nix
];
```

## Features in rain-custom.nix

- **4K HDR Monitor Support**: monitorv2 config with HDR color management
- **Custom Animations**: Smooth bezier curve animations
- **Media Window Positioning**: PiP window management for mpv and Firefox
- **Custom Keybindings**:
  - `SUPER + CTRL + H/J/K/L` - Position media windows (vim-like)
  - `SUPER + Menu` - Wallpaper roulette
  - `SUPER + T/F/A/C/M` - Focus or launch apps
  - `SUPER + ALT + 1-0` - Isolate focused window to workspace
- **Window Rules**: Special handling for Steam, Jellyfin, PiP windows
- **Custom Scripts**: Audio toggle, media window management, etc.

## Scripts

All scripts in `user-scripts/` are automatically packaged and made available:

- `audio-toggle.sh` - Toggle audio with custom behavior
- `focus-or-launch.sh` - Focus existing window or launch new app
- `move-media-window.sh` - Position media windows precisely
- `isolate-focused-window.sh` - Move all other windows to different workspace
- `fullscreen-media-toggle.sh` - Toggle fullscreen with state saving
- And more...

## Customization

You can override any settings by adding them after importing the modules:

```nix
wayland.windowManager.hyprland.settings = {
  general.gaps_in = 10;  # Override gaps
  decoration.rounding = 15;  # More rounding
};
```

