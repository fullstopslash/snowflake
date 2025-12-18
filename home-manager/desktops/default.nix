# Home-manager configuration for desktop environment
# Package installation managed via modules/apps/
# Enable via: myModules.apps.window-managers.hyprland.enable = true;
#             myModules.apps.desktop.{rofi,waybar,dunst}.enable = true;
{ ... }:
{
  imports = [
    # Packages with custom configs go here

    ./hyprland

    ########## Utilities ##########
    ./services/dunst.nix # Notification daemon
    ./waybar.nix # infobar
    ./rofi.nix # app launcher
    #./playerctl.nix # cli util and lib for controlling media players that implement MPRIS
    #./gtk.nix # mainly in gnome
  ];
  # Package installations moved to modules/apps/desktop/desktop.nix
}
