# Hyprland desktop module
#
# System-level hyprland configuration. User config files (keybinds, settings)
# should be managed via raw config files in ~/.config/hypr/, not in Nix.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.myModules.services.desktop.hyprland;
in
{
  options.myModules.services.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland desktop";
  };

  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
    };

    #
    # ========== System Packages ==========
    #
    environment.systemPackages = with pkgs; [
      # Cursor theme
      inputs.rose-pine-hyprcursor.packages.${pkgs.stdenv.hostPlatform.system}.default

      # Wayland utilities
      wl-clipboard # copy/paste
      wlr-randr # display config
      wdisplays # GUI display config
      waypaper # wallpaper manager

      # Screenshot/screen tools
      grim # screenshot
      slurp # region selection
      grimblast # screenshot helper

      # Notifications
      libnotify # notify-send
      dunst # notification daemon

      # Media controls
      playerctl # media player control
      brightnessctl # brightness control

      # App launchers
      wofi
      rofi # rofi-wayland merged into rofi

      # Misc utilities
      wlogout # logout menu
      hyprlock # screen locker
      hypridle # idle daemon
    ];

    #
    # ========== Environment Variables ==========
    #
    environment.sessionVariables = {
      # Wayland-specific
      NIXOS_OZONE_WL = "1"; # Electron/Chromium apps use Wayland
      MOZ_ENABLE_WAYLAND = "1"; # Firefox uses Wayland
      MOZ_WEBRENDER = "1"; # Firefox hardware rendering
      XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_DESKTOP = "Hyprland";

      # Cursor
      WLR_NO_HARDWARE_CURSORS = "1"; # software cursors (for VMs)
      HYPRCURSOR_THEME = "rose-pine-hyprcursor";
      XCURSOR_SIZE = "24";
      HYPRCURSOR_SIZE = "24";

      # Qt
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    };

    #
    # ========== XDG Portal ==========
    #
    xdg.portal = {
      enable = lib.mkDefault true;
      extraPortals = lib.mkDefault [ pkgs.xdg-desktop-portal-hyprland ];
    };

    #
    # ========== Security ==========
    #
    security.pam.services.hyprlock = { };
  };
}
