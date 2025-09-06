# Hyprland desktop role
{pkgs, ...}: {
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # KDE environment for Hyprland
  environment.sessionVariables = {
    # Color management for gamescope HDR support
    # HYPRLAND_DEBUG_FULL_CM_PROTO = "1";
    # KDE environment (suppress Hyprland warning)
    # XDG_CURRENT_DESKTOP = "KDE";
    # QT_QPA_PLATFORMTHEME = "kde";
    # QT_STYLE_OVERRIDE = "Breeze";
    # GTK_THEME = "Breeze";
    # XCURSOR_THEME = "breeze_cursors";
    # XCURSOR_SIZE = "24";
    # Qt scaling for Hyprland
    # QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    # QT_SCALE_FACTOR = "2.0";
    # QT_SCREEN_SCALE_FACTOR = "2.0";
    QT_ENABLE_HIGHDPI_SCALING = "1";
    # GDK_SCALE = "2";
    # GDK_DPI_SCALE = "2";
    # Performance optimizations
    # QT_LOGGING_RULES = "qt.qpa.*=false";
    # QT_ENABLE_GLYPH_CACHE_WORKAROUND = "1";
    # Suppress Hyprland warnings
    # HYPRLAND_NO_WARN = "1";
  };

  environment.systemPackages = with pkgs; [
    # KDE theming for Hyprland
    kdePackages.breeze-icons
    kdePackages.breeze-gtk
    kdePackages.breeze
    hyprpaper
    waybar
    eww
    rofi
    # Additional packages for waybar modules
    networkmanager
    wirelesstools
    lm_sensors
    radeontop
    playerctl
    helvum
    brightnessctl
    wireplumber
    dunst
    # Fonts for better scaling
    jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    # Additional scaling support
    xdg-utils
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    # Tray/dbusmenu helpers for Waybar
    libdbusmenu-gtk3
    libayatana-appindicator
  ];

  # Systemd user services
  systemd.user.services = {
    hyprpaper = {
      description = "Hyprland wallpaper daemon";
      wantedBy = ["hyprland-session.target"];
      partOf = ["hyprland-session.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.hyprpaper}/bin/hyprpaper";
        Restart = "on-failure";
        RestartSec = 1;
        # Add delay to ensure Wayland is ready
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 1";
      };
    };

    dunst = {
      description = "Dunst notification daemon";
      wantedBy = ["hyprland-session.target"];
      partOf = ["hyprland-session.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.dunst}/bin/dunst";
        Restart = "on-failure";
        RestartSec = 1;
      };
    };

    waybar = {
      description = "Waybar status bar";
      wantedBy = ["hyprland-session.target"];
      partOf = ["hyprland-session.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.waybar}/bin/waybar";
        Restart = "on-failure";
        RestartSec = 1;
        Environment = "PATH=${pkgs.lib.makeBinPath [pkgs.hyprland pkgs.rofi pkgs.networkmanager pkgs.playerctl pkgs.helvum pkgs.brightnessctl pkgs.wireplumber pkgs.dunst]}";
        # Add delay to ensure Wayland is ready
        # ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
      };
    };

    # Systemd user service for syncthing tray (Hyprland)
    # syncthingtray = {
    #   description = "Syncthing Tray";
    #   wantedBy = ["hyprland-session.target"];
    #   after = ["hyprland-session.target"];
    #   serviceConfig = {
    #     Type = "simple";
    #     ExecStart = "${pkgs.syncthingtray}/bin/syncthingtray --wait";
    #     Restart = "on-failure";
    #     RestartSec = "5";
    #   };
    #   environment = {
    #     DISPLAY = ":0";
    #   };
    # };

    kdeconnect-indicator = {
      description = "KDE Connect indicator";
      wantedBy = ["hyprland-session.target"];
      partOf = ["hyprland-session.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnect-indicator";
        Restart = "on-failure";
        RestartSec = 1;
        Environment = "PATH=${pkgs.lib.makeBinPath [pkgs.kdePackages.kdeconnect-kde]}";
      };
    };
  };
}
