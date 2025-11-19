# Desktop environment role
{
  config,
  pkgs,
  ...
}: {
  # Allow insecure packages specifically required for the desktop role
  nixpkgs.config.permittedInsecurePackages = [
    "ventoy-1.1.07"
    "ventoy-qt5-1.1.07"
  ];

  xdg.mime.enable = true;

  # Display manager and desktop services
  services = {
    hardware.openrgb.enable = true;
    printing.enable = true;
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
    firefox = {
      enable = true;
      nativeMessagingHosts.packages = [
        pkgs.tridactyl-native
      ];
    };
    kdeconnect.enable = true;
  };

  systemd = {
    services = {
      # post-sleep = {
      #   description = "Post-sleep script";
      #   after = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
      #   wantedBy = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
      #   serviceConfig = {
      #     Type = "oneshot";
      #     ExecStart = "${pkgs.curl}/bin/curl https://ntfy.chimera-micro.ts.net/waterbug-alerts -d 'Resumed: \"post sleep\"' -H 'Tags: skull' ";
      #     User = "rain";
      #   };
      # };
      post-sleep-samsung = {
        description = "Post-sleep script";
        after = ["suspend.target" "hibernate.target" "hybrid-sleep.target" "network-online.target"];
        wants = ["network-online.target"];
        wantedBy = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.home-assistant-cli}/bin/hass-cli service call media_player.turn_off --arguments entity_id=media_player.abysmal";
          User = "rain";
          Environment = [
            "HOME=/home/rain"
            "XDG_RUNTIME_DIR=/run/user/1000"
          ];
          EnvironmentFile = [
            config.sops.templates."post-sleep-samsung.env".path
          ];
          TimeoutStopSec = "30s";
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

  sops.secrets = {
    env_hass_server = {key = "env_hass_server";};
    env_hass_token = {key = "env_hass_token";};
  };

  sops.templates."post-sleep-samsung.env" = {
    content = ''
      HASS_SERVER=${config.sops.placeholder."env_hass_server"}
      HASS_TOKEN=${config.sops.placeholder."env_hass_token"}
    '';
    owner = "rain";
    mode = "0400";
  };

  # System packages for desktop
  environment.systemPackages = with pkgs; [
    # Browsers
    firefox
    ungoogled-chromium
    microsoft-edge
    # floorp-bin
    ladybird

    # Desktop utilities
    input-leap
    darkman
    pywal16
    wallust
    wofi
    lua
    wev
    ydotool
    # karakeep
    # ventoy-full-qt
    # ventoy

    # Terminal
    ghostty
    kitty
    alacritty
    rio

    # Terminal Toys
    neo
    tmatrix

    #Development utils for Desktop
    freetype
    ncurses
    gettext
    xorg.libXcursor

    # File management
    xfce.thunar

    inkscape
    stable.calibre
    unrar

    upscayl
    upscayl-ncnn
    realesrgan-ncnn-vulkan
    genxword
    # stable.gitbutler

    # Email and password management
    thunderbird
    keepassxc

    # Wine with Wayland support
    wineWowPackages.waylandFull

    # Office
    obsidian
    anki
    anki-sync-server
    qimgv
    kdePackages.gwenview
    swayimg

    # Package managers
  ];
}
