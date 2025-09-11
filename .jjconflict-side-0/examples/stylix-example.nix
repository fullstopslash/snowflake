# Example: How to add stylix theming to a host
# Copy this pattern to your host configuration
{...}: {
  imports = [
    # ... your existing imports ...
    ../../roles/stylix.nix # Add this line
  ];

  # ... your existing configuration ...

  # Stylix theming configuration
  roles.stylix = {
    enable = true;

    # Choose your theme (see stylix.md for all options)
    theme = "catppuccin-mocha"; # Dark theme
    # theme = "catppuccin-latte"; # Light theme
    # theme = "dracula";
    # theme = "nord";
    # theme = "gruvbox-dark";

    # Set your wallpaper (place wallpapers in assets/wallpapers/)
    wallpaper = ../../assets/wallpapers/catppuccin-wall.jpg;
  };
}
