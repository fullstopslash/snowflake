# Hyprland desktop role
{pkgs, ...}: {
  programs.hyprland = {
    enable = true;
    portalPackage = pkgs.kdePackages.xdg-desktop-portal-kde;
    xwayland.enable = true;
  };

  # Environment for Hyprland
  environment.sessionVariables = {
    # Color management for gamescope HDR support
    # HYPRLAND_DEBUG_FULL_CM_PROTO = "1";
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

  # xdg-desktop-portal configuration
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
      kdePackages.xdg-desktop-portal-kde
    ];
    # Common fallback so behavior is sane even if desktop detection differs
    config.common = {
      default = ["hyprland" "kde" "gtk"];
      "org.freedesktop.impl.portal.FileChooser" = "kde";
      "org.freedesktop.impl.portal.OpenURI" = "gtk";
    };
    # Restrict default order, prefer KDE chooser, but use GTK for OpenURI
    config.hyprland = {
      default = ["hyprland" "gtk"];
    };
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
    # KDE runtime deps to make Dolphin behave outside Plasma
    kdePackages.kio
    kdePackages.kio-extras
    kdePackages.kde-cli-tools
    kdePackages.kdialog
    kdePackages.xdg-desktop-portal-kde
  ];

  # Systemd user services
  systemd.user.services = {
    # Ensure portal environment is correct for Hyprland session only
    portal-env = {
      description = "Set portal environment for Hyprland";
      wantedBy = ["hyprland-session.target"];
      partOf = ["hyprland-session.target"];
      before = ["xdg-desktop-portal.service" "xdg-desktop-portal-hyprland.service"];
      serviceConfig = {
        Type = "oneshot";
        Environment = "XDG_CURRENT_DESKTOP=Hyprland:KDE";
        ExecStart = [
          "${pkgs.systemd}/bin/systemctl --user import-environment XDG_CURRENT_DESKTOP WAYLAND_DISPLAY"
          "${pkgs.dbus}/bin/dbus-update-activation-environment --systemd XDG_CURRENT_DESKTOP WAYLAND_DISPLAY"
        ];
      };
    };
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
