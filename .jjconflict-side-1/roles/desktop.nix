# Desktop environment role
{pkgs, ...}: {
  # Allow insecure packages specifically required for the desktop role
  nixpkgs.config.permittedInsecurePackages = [
    "ventoy-1.1.07"
    "ventoy-qt5-1.1.07"
  ];

  # Display manager and desktop services
  services = {
    # Display manager / desktop moved to roles/plasma.nix and roles/hyprland.nix
    power-profiles-daemon.enable = true;
    pipewire = {
      raopOpenFirewall = true;
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
      wireplumber.enable = true;
      extraConfig.pipewire = {
        "10-airplay" = {
          "context.modules" = [
            {
              name = "libpipewire-module-raop-discover";
            }
          ];
        };
      };
    };
    libinput.enable = true;
    fwupd.enable = true;
  };

  # Desktop programs
  programs = {
    kdeconnect.enable = true;
  };

  systemd = {
    services = {
      post-sleep = {
        description = "Post-sleep script";
        after = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
        wantedBy = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.curl}/bin/curl https://ntfy.chimera-micro.ts.net/waterbug-alerts -d 'Resumed: \"post sleep\"' -H 'Tags: skull' ";
          User = "rain";
        };
      };

      post-sleep-samsung = {
        description = "Post-sleep script";
        after = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
        wantedBy = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.home-assistant-cli}/bin/hass-cli ";
          User = "rain";
        };
      };

      # Fix audio routing after resume (restart PipeWire/WirePlumber and prefer HDMI/DP)
      "audio-fix-after-sleep" = {
        description = "Fix PipeWire audio routing after suspend/resume";
        after = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
        wantedBy = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
        serviceConfig = {
          Type = "oneshot";
          User = "rain";
          ExecStart = "${pkgs.writeShellScript "hypr-audio-resume" ''
            #!/usr/bin/env sh
            set -eu
            # Restart user audio daemons
            sleep .1;
            systemctl --user restart wireplumber.service pipewire.service pipewire-pulse.service >/dev/null 2>&1 || true
            # Restart EasyEffects if available
            if systemctl --user list-unit-files | ${pkgs.gnugrep}/bin/grep -q '^easyeffects'; then
              systemctl --user restart easyeffects.service >/dev/null 2>&1 || true
            fi
            if systemctl --user list-units | ${pkgs.gnugrep}/bin/grep -q 'easyeffects-daemon.service'; then
              systemctl --user restart easyeffects-daemon.service >/dev/null 2>&1 || true
            fi
            # Allow devices to reappear
            ${pkgs.coreutils}/bin/sleep 1
            # Prefer EasyEffects virtual sink if present
            EESINK_ID=$(\
              ${pkgs.wireplumber}/bin/wpctl status |
              ${pkgs.gawk}/bin/awk 'f{if($0 ~ /^\\s*[0-9]+\\./){print}} /Sinks:/{f=1} /Sources:/{f=0}' |
              ${pkgs.gnugrep}/bin/grep -iE 'easy.*effects' |
              ${pkgs.gnused}/bin/sed -n 's/^\\s*\\([0-9]\\+\\)\\..*/\\1/p' |
              ${pkgs.coreutils}/bin/head -n1
            ) || true
            if [ -n ''${EESINK_ID:-} ]; then
              ${pkgs.wireplumber}/bin/wpctl set-default "$EESINK_ID" >/dev/null 2>&1 || true
              exit 0
            fi
            # Otherwise choose an HDMI/DP sink if present and set it as default
            SINK_ID=$(\
              ${pkgs.wireplumber}/bin/wpctl status |
              ${pkgs.gawk}/bin/awk 'f{if($0 ~ /^\\s*[0-9]+\\./){print}} /Sinks:/{f=1} /Sources:/{f=0}' |
              ${pkgs.gnugrep}/bin/grep -iE 'hdmi|display|monitor|dp' |
              ${pkgs.gnused}/bin/sed -n 's/^\\s*\\([0-9]\\+\\)\\..*/\\1/p' |
              ${pkgs.coreutils}/bin/head -n1
            ) || true
            if [ -n ''${SINK_ID:-} ]; then
              ${pkgs.wireplumber}/bin/wpctl set-default "$SINK_ID" >/dev/null 2>&1 || true
            fi
            exit 0
          ''}";
        };
      };
    };

    user.services = {
      post-sleep-graphical = {
        description = "User post-sleep script";
        after = ["graphical-session.target"];
        wantedBy = ["default.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.curl}/bin/curl https://ntfy.chimera-micro.ts.net/waterbug-alerts -d 'Resumed: \"Graphical-session\"' -H 'Tags: skull' ";
          RemainAfterExit = true;
        };
      };

      mpris-proxy = {
        description = "Mpris proxy";
        after = ["network.target" "sound.target"];
        wantedBy = ["default.target"];
        serviceConfig.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
      };

      lnxlink = {
        description = "lnxlink homeassistant integration";
        after = ["network.target"];
        wantedBy = ["default.target"];
        serviceConfig.ExecStart = "%h/.local/share/mise/installs/pipx-lnxlink/2025.7.0/bin/lnxlink -c ~/.config/lnxlink/config.yaml";
      };
    };
  };

  # System packages for desktop
  environment.systemPackages = with pkgs; [
    # Desktop utilities
    input-leap
    pywal16
    wallust
    wofi
    lua
    wev
    karakeep
    # ventoy-full-qt
    # ventoy

    #Development utils for Desktop
    meld
    freetype
    ncurses
    gettext
    xorg.libXcursor

    # File management
    xfce.thunar

    inkscape
    calibre
    unrar

    upscayl
    upscayl-ncnn
    realesrgan-ncnn-vulkan
    genxword

    # Office
    obsidian
    anki
    anki-sync-server

    # Package managers
  ];
}
