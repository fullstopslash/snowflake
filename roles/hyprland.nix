# Hyprland desktop role
{
  pkgs,
  lib,
  ...
}: let
  hypridleConf = pkgs.writeText "hypridle.conf" ''
    general {
      before_sleep_cmd = ${pkgs.hyprlock}/bin/hyprlock
      after_sleep_cmd = ${pkgs.hyprland}/bin/hyprctl dispatch dpms on
    }
  '';
in {
  programs = {
    hyprland = {
      enable = true;
      # portalPackage = pkgs.xdg-desktop-portal-hyprland;
      xwayland.enable = true; # Re-enabled for SDDM compatibility
    };
    hyprlock.enable = true;
  };

  services.hypridle.enable = true;

  # Display manager is handled by greetd.nix role
  services.displayManager.defaultSession = "hyprland";

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
    # Ensure Hyprland picks the Stylix cursor theme/colors
    XCURSOR_THEME = "Nordzy-catppuccin-mocha-dark";
    XCURSOR_SIZE = "24";
    HYPRCURSOR_THEME = "Nordzy-catppuccin-mocha-dark";
    HYPRCURSOR_SIZE = "24";
    # GDK_SCALE = "2";
    # GDK_DPI_SCALE = "2";
    # Performance optimizations
    # QT_LOGGING_RULES = "qt.qpa.*=false";
    # QT_ENABLE_GLYPH_CACHE_WORKAROUND = "1";
    # Suppress Hyprland warnings
    # HYPRLAND_NO_WARN = "1";
  };

  # xdg-desktop-portal configuration
  # xdg.portal = {
  #   enable = true;
  #   extraPortals = with pkgs; [
  #     xdg-desktop-portal-hyprland
  #     # xdg-desktop-portal-gtk
  #     # kdePackages.xdg-desktop-portal-kde
  #   ];
  #   # Common fallback so behavior is sane even if desktop detection differs
  #   config.common = {
  #     default = ["hyprland" "gtk"];
  #     "org.freedesktop.impl.portal.FileChooser" = "hyprland";
  #     "org.freedesktop.impl.portal.OpenURI" = "hyprland";
  #   };
  #   # Restrict default order, prefer KDE chooser, but use GTK for OpenURI
  #   config.hyprland = {
  #     default = ["hyprland" "gtk"];
  #   };
  # };

  environment.systemPackages = with pkgs; [
    # Hyprland utilities
    hyprlock
    hyprpicker
    hypridle
    hyprls
    kdePackages.kwallet
    kdePackages.kwallet-pam
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
    # Tray/dbusmenu helpers for Waybar
    libdbusmenu-gtk3
    libayatana-appindicator
    # KDE runtime deps to make Dolphin behave outside Plasma
    kdePackages.kio
    kdePackages.kio-extras
    kdePackages.kde-cli-tools
    kdePackages.kdialog
    # kdePackages.xdg-desktop-portal-kde

    # Anki wrapper with Wayland-safe flags (Hyprland)
    (writeShellScriptBin "anki-wayland" ''
      #!/usr/bin/env sh
      ANKI_WAYLAND=1 \
      QT_QPA_PLATFORM=wayland \
      QTWEBENGINE_CHROMIUM_FLAGS="--disable-gpu --disable-gpu-compositing --in-process-gpu" \
      exec ${anki}/bin/anki "$@"
    '')

    # Desktop entry shown only in Hyprland sessions
    (writeTextFile {
      name = "anki-wayland-desktop";
      destination = "/share/applications/anki-wayland.desktop";
      text = ''
        [Desktop Entry]
        Type=Application
        Name=Anki (Wayland)
        Comment=Anki with Wayland-safe flags for Hyprland
        Exec=anki-wayland %U
        Icon=anki
        Terminal=false
        Categories=Education;
        OnlyShowIn=Hyprland;
      '';
    })
  ];

  # PAM integration for hyprlock
  security.pam.services.hyprlock = {};
  # Unlock KWallet at login for Hyprland sessions too
  security.pam.services = {
    login.kwallet.enable = true;
    sddm.kwallet.enable = true;
    sddm-greeter.kwallet.enable = true;
  };

  services.dbus.enable = true;
  programs.dconf.enable = true;

  # Systemd user services
  systemd.user.services = {
    kwalletd = {
      wantedBy = ["hyprland-session.target" "default.target"];
      partOf = ["hyprland-session.target"];
      after = ["hyprland-session.target" "dbus.service"];
    };
    hypridle = {
      description = "Hypridle lock handler";
      wantedBy = ["hyprland-session.target"];
      partOf = ["hyprland-session.target"];
      after = ["hyprland-session.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.hypridle}/bin/hypridle -c ${hypridleConf}";
        Restart = "on-failure";
        RestartSec = 1;
        Environment = "PATH=${pkgs.lib.makeBinPath [pkgs.hyprland pkgs.hyprlock pkgs.coreutils]}";
      };
    };
    # Ensure portal environment is correct for Hyprland session only
    portal-env = {
      description = "Set portal environment for Hyprland";
      wantedBy = ["hyprland-session.target"];
      partOf = ["hyprland-session.target"];
      before = ["xdg-desktop-portal.service" "xdg-desktop-portal-hyprland.service"];
      serviceConfig = {
        Type = "oneshot";
        Environment = "XDG_CURRENT_DESKTOP=Hyprland";
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
        Environment = "PATH=/run/current-system/sw/bin:/bin:%h/.local/bin";
        WorkingDirectory = "%h/.config/waybar";
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

    # xwaylandvideobridge-hide = {
    #   description = "Hide xwayland video bridge utility window";
    #   wantedBy = ["hyprland-session.target"];
    #   partOf = ["hyprland-session.target"];
    #   after = ["hyprland-session.target"];
    #   serviceConfig = {
    #     Type = "oneshot";
    #     ExecStart = pkgs.writeShellScript "hide-xwaylandvideobridge" ''
    #       #!/usr/bin/env sh
    #       set -eu
    #       # Apply runtime rules to hide and prevent focus on the bridge window
    #       ${pkgs.hyprland}/bin/hyprctl keyword windowrulev2 "opacity 0.0 override,class:^(xwaylandvideobridge)$"
    #       ${pkgs.hyprland}/bin/hyprctl keyword windowrulev2 "nofocus,class:^(xwaylandvideobridge)$"
    #       ${pkgs.hyprland}/bin/hyprctl keyword windowrulev2 "noanim,class:^(xwaylandvideobridge)$"
    #       # Also match by common window title just in case
    #       ${pkgs.hyprland}/bin/hyprctl keyword windowrulev2 "opacity 0.0 override,title:^(Wayland to X.*bridge)$"
    #       ${pkgs.hyprland}/bin/hyprctl keyword windowrulev2 "nofocus,title:^(Wayland to X.*bridge)$"
    #       ${pkgs.hyprland}/bin/hyprctl keyword windowrulev2 "noanim,title:^(Wayland to X.*bridge)$"
    #     '';
    #   };
    # };

    # # Ensure EasyEffects sink is default at session start so Waybar controls it
    # prefer-easyeffects-sink = {
    #   description = "Prefer EasyEffects virtual sink as default";
    #   wantedBy = ["hyprland-session.target"];
    #   partOf = ["hyprland-session.target"];
    #   after = ["hyprland-session.target" "wireplumber.service" "pipewire.service" "pipewire-pulse.service"];
    #   serviceConfig = {
    #     Type = "oneshot";
    #     ExecStart = pkgs.writeShellScript "prefer-ee-sink" ''
    #       #!/usr/bin/env sh
    #       set -eu
    #       # Allow pipewire graph to settle
    #       ${pkgs.coreutils}/bin/sleep 1
    #       EE_SINK=$(${pkgs.wireplumber}/bin/wpctl status | ${pkgs.gnugrep}/bin/grep -iE 'Sinks:' -A 50 | ${pkgs.gnugrep}/bin/grep -iE 'easy.*effects' | ${pkgs.gnused}/bin/sed -n 's/^\\s*\\([0-9]\\+\\)\\..*/\\1/p' | ${pkgs.coreutils}/bin/head -n1 || true)
    #       if [ -n ''${EE_SINK:-} ]; then
    #         ${pkgs.wireplumber}/bin/wpctl set-default "$EE_SINK" >/dev/null 2>&1 || true
    #       fi
    #       exit 0
    #     '';
    #   };
    # };
  };
}
