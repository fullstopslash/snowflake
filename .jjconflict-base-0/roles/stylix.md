# Stylix Theming Role

This role provides modular theming capabilities using [Stylix](https://github.com/danth/stylix), a NixOS module that automatically generates consistent themes across your entire system.

## Features

- **Theme Presets**: Pre-configured popular themes like Catppuccin, Dracula, Gruvbox, Nord, and more
- **Modular Design**: Easy to enable/disable for specific hosts
- **Comprehensive Coverage**: Themes GTK, Qt, KDE, GNOME, i3, Sway, and many other environments
- **Customizable**: Support for custom base16 schemes and wallpapers
- **Font Management**: Automatic font configuration with popular font families

## Usage

### Basic Setup

Add the stylix role to your host configuration:

```nix
# hosts/myhost/default.nix
{...}: {
  imports = [
    ../../roles/stylix.nix
  ];

  roles.stylix = {
    enable = true;
    theme = "catppuccin-mocha";
    wallpaper = ../../assets/wallpapers/my-wallpaper.jpg;
  };
}
```

### Available Themes

- `catppuccin-mocha` - Dark Catppuccin theme (default)
- `catppuccin-macchiato` - Medium Catppuccin theme
- `catppuccin-frappe` - Medium-light Catppuccin theme
- `catppuccin-latte` - Light Catppuccin theme
- `dracula` - Dracula theme
- `gruvbox-dark` - Dark Gruvbox theme
- `gruvbox-light` - Light Gruvbox theme
- `nord` - Nord theme
- `tokyonight` - Tokyo Night theme
- `rose-pine` - Rose Pine theme
- `everforest` - Everforest theme
- `kanagawa` - Kanagawa theme
- `onedark` - One Dark theme
- `solarized-dark` - Dark Solarized theme
- `solarized-light` - Light Solarized theme
- `custom` - Use custom base16 scheme

### Advanced Configuration

For custom themes, you can provide your own base16 scheme:

```nix
roles.stylix = {
  enable = true;
  theme = "custom";
  base16Scheme = ../../schemes/my-custom-theme.yaml;
  wallpaper = ../../assets/wallpapers/custom-wall.jpg;
};
```

### Custom Base16 Scheme

For custom themes, you can provide your own base16 scheme:

```nix
roles.stylix = {
  enable = true;
  theme = "custom";
  base16Scheme = ../../schemes/my-custom-theme.yaml;
  wallpaper = ../../assets/wallpapers/custom-wall.jpg;
};
```

### Wallpaper Management

Place your wallpapers in the `assets/wallpapers/` directory:

```
assets/
└── wallpapers/
    ├── catppuccin-wall.jpg
    ├── dracula-wall.jpg
    ├── nord-wall.jpg
    └── custom-wall.jpg
```

## Integration with Other Roles

The stylix role works well with other desktop roles:

- **Hyprland**: Automatically themes Hyprland with your chosen scheme
- **Plasma**: Provides consistent theming across KDE applications
- **i3/Sway**: Themes window managers and their components
- **GTK/Qt**: Ensures consistent appearance across all applications

## Troubleshooting

### Theme Not Applying

1. Ensure the role is properly imported in your host configuration
2. Check that the wallpaper path is correct and the file exists
3. Verify that the theme name is spelled correctly
4. Run `nix flake check` to validate your configuration

### Custom Scheme Issues

1. Ensure your base16 scheme follows the correct YAML format
2. Verify the scheme file path is correct
3. Check that the scheme includes all required color definitions

### Font Issues

1. Ensure the font packages are available in nixpkgs
2. Verify font family names match the installed fonts
3. Check that the font packages are included in the system packages

### Cursor Theme Issues

1. **Cursor not changing**: The cursor theme might not apply immediately. Try:
   - Logging out and back in
   - Restarting your desktop environment
   - Running `gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Classic"` (for GNOME)
   - Running `gsettings set org.gnome.desktop.interface cursor-size 24` (for GNOME)

2. **Available cursor themes**: The default configuration uses `Bibata-Modern-Classic`. Other available themes include:
   - `Bibata-Modern-Ice`
   - `Bibata-Modern-Amber`
   - `Bibata-Original-Classic`
   - `Bibata-Original-Ice`
   - `Bibata-Original-Amber`

3. **Check current cursor theme**: You can check what cursor theme is currently active with:
   ```bash
   gsettings get org.gnome.desktop.interface cursor-theme
   echo $XCURSOR_THEME
   ```

4. **Force cursor theme**: If the theme still doesn't apply, you can manually set it:
   ```bash
   # For X11
   xsetroot -cursor_name left_ptr
   
   # For Wayland (in your shell profile)
   export XCURSOR_THEME="Bibata-Modern-Classic"
   export XCURSOR_SIZE=24
   ```

## Examples

### Minimal Setup (Catppuccin Mocha)

```nix
roles.stylix = {
  enable = true;
  theme = "catppuccin-mocha";
  wallpaper = ../../assets/wallpapers/catppuccin.jpg;
};
```

### Light Theme Setup

```nix
roles.stylix = {
  enable = true;
  theme = "catppuccin-latte";
  wallpaper = ../../assets/wallpapers/light-wall.jpg;
};
```

### Custom Theme Example

```nix
roles.stylix = {
  enable = true;
  theme = "custom";
  base16Scheme = ../../schemes/my-theme.yaml;
  wallpaper = ../../assets/wallpapers/my-wall.jpg;
};
```

## Notes

- The role automatically handles font installation and configuration
- Cursor themes are automatically applied system-wide
- GTK and Qt applications will be themed consistently
- The role is designed to work with your existing desktop environment configurations
- All theme changes are applied system-wide and persist across reboots

