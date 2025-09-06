# Desktop environment role
{pkgs, ...}: {
  # Allow insecure packages specifically required for the desktop role
  nixpkgs.config.permittedInsecurePackages = [
    "ventoy-1.1.05"
    "ventoy-qt5-1.1.05"
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
    services.post-sleep = {
      description = "Post-sleep script";
      after = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
      wantedBy = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.curl}/bin/curl https://ntfy.chimera-micro.ts.net/waterbug-alerts -d 'Resumed: \"post sleep\"' -H 'Tags: skull' ";
        User = "rain";
      };
    };

    services.post-sleep-samsung = {
      description = "Post-sleep script";
      after = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
      wantedBy = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.home-assistant-cli}/bin/hass-cli ";
        User = "rain";
      };
    };

    user.services = {
      post-sleep-graphical = {
        description = "User post-sleep script";
        after = ["graphical-session.target"];
        wantedBy = ["default.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.curl}/bin/curl https://ntfy.chimera-micro.ts.net/waterbug-alerts -d 'Resumed: \"Graphical\"' -H 'Tags: skull' ";
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
    ventoy-full-qt
    ventoy

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
    # FIX: Running from stable
    stable.anki
    stable.anki-sync-server

    # Package managers
  ];
}
