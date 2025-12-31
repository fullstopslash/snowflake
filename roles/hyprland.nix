# Hyprland desktop role
{
  pkgs,
  lib,
  inputs,
  ...
}: let
  hypridleConf = pkgs.writeText "hypridle.conf" ''
    general {
      lock_cmd = pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock
      before_sleep_cmd = loginctl lock-session
      after_sleep_cmd = ${pkgs.hyprland}/bin/hyprctl dispatch dpms on
    }

    # Dim screen after 4 minutes
    listener {
      timeout = 240
      on-timeout = ${pkgs.brightnessctl}/bin/brightnessctl -s set 10%
      on-resume = ${pkgs.brightnessctl}/bin/brightnessctl -r
    }

    # Lock screen after 5 minutes
    listener {
      timeout = 300
      on-timeout = loginctl lock-session
    }

    # Turn off screen after 6 minutes
    listener {
      timeout = 360
      on-timeout = ${pkgs.hyprland}/bin/hyprctl dispatch dpms off
      on-resume = ${pkgs.hyprland}/bin/hyprctl dispatch dpms on
    }

    # Suspend after 10 minutes
    listener {
      timeout = 600
      on-timeout = systemctl suspend
    }
  '';
in {
  programs = {
    hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.system}.hyprland;
      # portalPackage = pkgs.xdg-desktop-portal-hyprland;
      xwayland.enable = true; # Required for X11 apps like LM Studio
    };
    hyprlock.enable = true;
  };

  # hypridle is configured via systemd.user.services.hypridle below
  # services.hypridle.enable = true; # Disabled to avoid conflict with custom service

  # Display manager is handled by greetd.nix role
  services.displayManager.defaultSession = "hyprland";

  # Place hypridle config in /etc/hypr/ so hypridle can find it
  environment.etc."hypr/hypridle.conf".source = hypridleConf;

  # Environment for Hyprland
  environment.sessionVariables = {
    # Color management for gamescope HDR support
    # HYPRLAND_DEBUG_FULL_CM_PROTO = "1";
    # QT_QPA_PLATFORMTHEME = "kde";
    # QT_STYLE_OVERRIDE = "Breeze";
    # GTK_THEME = "Breeze";
    # XCURSOR_THEME = "breeze_cursors";
    # XCURSOR_SIZE = "24";
    # Qt scaling for Hyprland and X11 applications
    QT_ENABLE_HIGHDPI_SCALING = "1";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    # X11 DPI for Xwayland applications
    XCURSOR_THEME = "Nordzy-catppuccin-mocha-dark";
    XCURSOR_SIZE = "24";
    HYPRCURSOR_THEME = "Nordzy-catppuccin-mocha-dark";
    HYPRCURSOR_SIZE = "24";
    # Expose hyprscrolling plugin path (nixpkgs) so Hyprland can find it
    # HYPRLAND_PLUGIN_DIRS = "${pkgs.hyprlandPlugins.hyprscrolling}/lib";
    # GDK_SCALE = "2";
    # GDK_DPI_SCALE = "2";
    # Performance optimizations
    # QT_LOGGING_RULES = "qt.qpa.*=false";
    # QT_ENABLE_GLYPH_CACHE_WORKAROUND = "1";
    # Suppress Hyprland warnings
    # HYPRLAND_NO_WARN = "1";
  };

  # Provide a sane default Hyprland config in /etc that enables hyprscrolling layout.
  # If the user has ~/.config/hypr/hyprland.conf, Hyprland will prefer that instead.
  # Note: User config should use the full absolute path from ${pkgs.hyprlandPlugins.hyprscrolling}/lib/libhyprscrolling.so
  # The path will change when the package is updated, so update hyprland.conf accordingly.
  # environment.etc."hypr/hyprland.conf".text = ''
  #   plugin = ${pkgs.hyprlandPlugins.hyprscrolling}/lib/libhyprscrolling.so
  #   general {
  #     layout = scrolling
  #   }
  # '';

  # xdg-desktop-portal configuration
  # Note: xdg-desktop-portal-hyprland is automatically managed by programs.hyprland
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      # xdg-desktop-portal-hyprland is managed by programs.hyprland
      xdg-desktop-portal-gtk
      # kdePackages.xdg-desktop-portal-kde
    ];
    # Common fallback so behavior is sane even if desktop detection differs
    config.common = {
      default = ["hyprland" "gtk"];
      "org.freedesktop.impl.portal.FileChooser" = "hyprland";
      "org.freedesktop.impl.portal.OpenURI" = "hyprland";
    };
    # Restrict default order, prefer KDE chooser, but use GTK for OpenURI
    # config.hyprland = {
    #   default = ["hyprland" "gtk"];
    # };
  };

  environment.systemPackages = with pkgs; [
    # Hyprland utilities (use hyprpaper from hyprpaper flake for version compatibility)
    hyprlock
    hyprpicker
    hypridle
    hyprls
    inputs.hyprpaper.packages.${pkgs.system}.hyprpaper  # Use 0.8.0+ from hyprpaper flake
    hyprutils
    hyprlang
    kdePackages.kwallet
    kdePackages.dolphin
    kdePackages.okular
    kdePackages.kwallet-pam
    kdePackages.breeze-icons
    kdePackages.breeze-gtk
    kdePackages.breeze
    kdePackages.qtimageformats
    kdePackages.kimageformats
    # hyprlandPlugins.hyprscrolling
    waybar
    eww
    rofi
    # NetworkManager GUI tools
    networkmanagerapplet  # Provides nm-applet and nm-connection-editor
    networkmanager_dmenu  # Rofi/dmenu WiFi menu
    # Additional packages for waybar modules
    networkmanager
    wirelesstools
    lm_sensors
    radeontop
    brightnessctl
    wireplumber
    dunst
    # Fonts for better scaling
    jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    # Additional scaling support
    xdg-utils
    # X11 utilities for Xwayland DPI configuration
    xorg.xrdb
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

    # Streamlink Twitch GUI wrapper with improved X11 rendering
    (writeShellScriptBin "streamlink-twitch-gui" ''
      #!/usr/bin/env sh
      # Improve X11 rendering quality for streamlink-twitch-gui
      # Set high DPI and Qt scaling for crisp rendering through Xwayland

      # Set X11 DPI for Xwayland (96 DPI = 1x, 192 DPI = 2x scaling)
      # Adjust based on your display - 192 is good for 2x scaling
      export XCURSOR_SIZE=24

      # Qt scaling and high DPI support
      export QT_AUTO_SCREEN_SCALE_FACTOR=1
      export QT_ENABLE_HIGHDPI_SCALING=1
      export QT_SCALE_FACTOR=1

      # Force Qt to use X11/XCB platform explicitly for better rendering
      export QT_QPA_PLATFORM=xcb

      # Improve font rendering and disable shared memory for better quality
      export QT_X11_NO_MITSHM=1

      # Set X11 resources for high DPI (Xwayland will pick this up)
      # This improves rendering quality for X11 applications
      if command -v ${pkgs.xorg.xrdb}/bin/xrdb >/dev/null 2>&1; then
        echo "Xft.dpi: 192" | ${pkgs.xorg.xrdb}/bin/xrdb -merge 2>/dev/null || true
      fi

      exec ${pkgs.streamlink-twitch-gui-bin}/bin/streamlink-twitch-gui "$@"
    '')
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
    # Create symlink to hypridle config in user's home directory
    # This is needed because hypridle has a bug and doesn't find config in /etc/hypr/
    hypridle-config-setup = {
      description = "Setup hypridle config symlink";
      wantedBy = ["hyprland-session.target"];
      partOf = ["hyprland-session.target"];
      before = ["hypridle.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "setup-hypridle-config" ''
          #!/usr/bin/env sh
          mkdir -p ~/.config/hypr
          ln -sf /etc/hypr/hypridle.conf ~/.config/hypr/hypridle.conf
        '';
      };
    };

    hypridle = {
      description = "Hypridle lock handler";
      wantedBy = ["hyprland-session.target"];
      partOf = ["hyprland-session.target"];
      after = ["hyprland-session.target" "hypridle-config-setup.service"];
      serviceConfig = {
        Type = "simple";
        # Clear the default ExecStart first, then set our custom one
        # Config is linked from /etc/hypr/hypridle.conf to ~/.config/hypr/hypridle.conf
        ExecStart = [
          "" # Clear the ExecStart from the base service
          "${pkgs.hypridle}/bin/hypridle"
        ];
        Restart = "on-failure";
        RestartSec = 1;
        Environment = "PATH=${pkgs.lib.makeBinPath [pkgs.hyprland pkgs.hyprlock pkgs.brightnessctl pkgs.systemd pkgs.coreutils]}";
      };
    };
    # Wait for Hyprland compositor and export environment
    # This ensures WAYLAND_DISPLAY is set before other services start
    hyprland-environment = {
      description = "Wait for Hyprland compositor and export environment";
      wantedBy = ["hyprland-session.target"];
      partOf = ["hyprland-session.target"];
      before = ["xdg-desktop-portal.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "wait-for-hyprland" ''
          #!/usr/bin/env sh
          # Wait for Hyprland socket or WAYLAND_DISPLAY to be available
          for i in {1..30}; do
            if [ -n "$WAYLAND_DISPLAY" ] && [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
              # Wayland display is ready
              export XDG_CURRENT_DESKTOP=Hyprland
              ${pkgs.systemd}/bin/systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
              ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
              exit 0
            fi
            sleep 0.5
          done
          # Fallback: Set basic environment even if compositor not fully ready
          export XDG_CURRENT_DESKTOP=Hyprland
          ${pkgs.systemd}/bin/systemctl --user import-environment XDG_CURRENT_DESKTOP
          ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd XDG_CURRENT_DESKTOP
          exit 0
        '';
      };
    };
    hyprpaper = {
      description = "Hyprland wallpaper daemon";
      wantedBy = ["hyprland-session.target"];
      partOf = ["hyprland-session.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${inputs.hyprpaper.packages.${pkgs.system}.hyprpaper}/bin/hyprpaper";
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
      after = ["hyprland-environment.service"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnect-indicator";
        Restart = "on-failure";
        RestartSec = 5;
        Environment = [
          "PATH=${pkgs.lib.makeBinPath [pkgs.kdePackages.kdeconnect-kde]}"
          "QT_QPA_PLATFORM=wayland"
        ];
      };
    };

    nm-applet = {
      description = "NetworkManager applet";
      wantedBy = ["hyprland-session.target"];
      partOf = ["hyprland-session.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.networkmanagerapplet}/bin/nm-applet --indicator";
        Restart = "on-failure";
        RestartSec = 1;
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
