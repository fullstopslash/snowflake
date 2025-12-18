# Desktop environment common module
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  sopsFolder = builtins.toString inputs.nix-secrets + "/sops";
  hasDesktopSecrets = config.host.hasSecrets && config.host.secretCategories.desktop or false;
in
{
  description = "common desktop environment";
  config = {
    # Allow insecure packages specifically required for the desktop role
    nixpkgs.config.permittedInsecurePackages = [
      "ventoy-1.1.07"
      "ventoy-qt5-1.1.07"
    ];

    xdg.mime.enable = true;

    # Display manager and desktop services
    # NOTE: PipeWire config moved to modules/services/audio/pipewire.nix
    services = {
      hardware.openrgb.enable = true;
      printing.enable = true;
      # Display manager / desktop moved to roles/plasma.nix and roles/hyprland.nix
      power-profiles-daemon.enable = true;
      libinput.enable = true;
      fwupd.enable = true;
    };

    # Desktop programs
    programs = {
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
        post-sleep-samsung = lib.mkIf config.host.secretCategories.desktop {
          description = "Post-sleep script";
          after = [
            "suspend.target"
            "hibernate.target"
            "hybrid-sleep.target"
            "network-online.target"
          ];
          wants = [ "network-online.target" ];
          wantedBy = [
            "suspend.target"
            "hibernate.target"
            "hybrid-sleep.target"
          ];
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

        # NOTE: audio-fix-after-sleep moved to modules/services/audio/pipewire.nix
      };

      user.services = {
        post-sleep-graphical = {
          description = "User post-sleep script";
          after = [ "graphical-session.target" ];
          wantedBy = [ "default.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.curl}/bin/curl https://ntfy.chimera-micro.ts.net/waterbug-alerts -d 'Resumed: \"Graphical-session\"' -H 'Tags: skull' ";
            RemainAfterExit = true;
          };
        };

        # NOTE: mpris-proxy moved to modules/services/audio/pipewire.nix

        lnxlink = {
          description = "lnxlink homeassistant integration";
          after = [ "network.target" ];
          wantedBy = [ "default.target" ];
          serviceConfig.ExecStart = "%h/.local/share/mise/installs/pipx-lnxlink/2025.7.0/bin/lnxlink -c ~/.config/lnxlink/config.yaml";
        };
      };
    };

    # HASS secrets for desktop services (post-sleep, etc.)
    sops.secrets = lib.mkIf hasDesktopSecrets {
      "env_hass_server" = {
        sopsFile = "${sopsFolder}/shared.yaml";
      };
      "env_hass_token" = {
        sopsFile = "${sopsFolder}/shared.yaml";
      };
    };

    # Environment template for HASS services
    sops.templates."post-sleep-samsung.env" = lib.mkIf hasDesktopSecrets {
      content = ''
        HASS_SERVER=${config.sops.placeholder."env_hass_server"}
        HASS_TOKEN=${config.sops.placeholder."env_hass_token"}
      '';
      owner = config.host.username;
      mode = "0400";
    };

    # System packages for desktop
    environment.systemPackages = with pkgs; [
      # Browsers - now managed via modules/apps/browsers/ modules
      # See: modules/apps/browsers/{firefox,chromium,microsoft-edge,ladybird}.nix

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
      qview
      kdePackages.gwenview
      swayimg

      # Package managers
    ];
  };
}
