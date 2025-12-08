# Gaming role
{ pkgs, ... }:
{
  # Steam Controller settings
  hardware.steam-hardware.enable = true;

  # Gaming programs
  programs = {
    gamemode = {
      enable = true;
    };
    gamescope = {
      enable = true;
      # Enable CAP_SYS_NICE for better performance
      capSysNice = true;
    };
    steam = {
      enable = true;
      gamescopeSession.enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      extraCompatPackages = with pkgs; [
        proton-ge-bin
        # mcpelauncher-ui-qt
        # mcpelauncher-client
      ];
    };
  };

  # Virtualization for gaming
  virtualisation = {
    waydroid.enable = true;
    docker = {
      enable = true;
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
      daemon.settings = {
        data-root = "/home/rain/docker/images/";
      };
    };
  };

  services.sunshine = {
    enable = true;
    autoStart = false;
    capSysAdmin = true;
    openFirewall = true;
  };

  # udev rules for gaming controllers
  services.udev.extraRules = ''
    SUBSYSTEM=="input", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0660", GROUP="input"
  '';

  # Gaming packages
  environment.systemPackages = with pkgs; [
    # Games
    cataclysm-dda-git
    crawl
    crawlTiles
    brogue-ce
    # stable.tome4
    # Dwarf Fortress
    stable.dwarf-fortress

    # Gaming utilities
    steamtinkerlaunch
    bottles
    stable.lutris
    protontricks
    protonup-qt
    nexusmods-app
    playonlinux
    winetricks
    vulkan-tools

    # Game development
    godot3
    SDL2
    SDL2_image
    SDL2_mixer
    SDL2_ttf
    freetype
    ncurses
    gettext
    xorg.libXcursor

    # Gaming tools
    dualsensectl
    moonlight-qt
    antimicrox
    stable.starsector
    ryubing
    freeciv
    winetricks
    usbutils

    # Gaming utilities
    mangohud
    mangojuice

    # gamescope
    #   (writeShellScriptBin "gamescope-hdr" ''
    #     #!/usr/bin/env sh
    #     # Default HDR-friendly gamescope invocation; pass through all args
    #     # Disable Vulkan HDR layer inside Gamescope to avoid conflicts
    #     ENABLE_HDR_WSI= \
    #     exec ${pkgs.gamescope}/bin/gamescope \
    #       -H --hdr-enabled --hdr-itm-enable --prefer-output-color-space bt2020-pq \
    #       -- ${"$@"}
    #   '')
    #
    #   (writeShellScriptBin "steam-bp-hdr" ''
    #     #!/usr/bin/env sh
    #     # Launch Steam Big Picture inside Gamescope with HDR defaults
    #     # Disable Vulkan HDR layer inside Gamescope to avoid conflicts
    #     ENABLE_HDR_WSI= \
    #     exec ${pkgs.gamescope}/bin/gamescope \
    #       -H --hdr-enabled --hdr-itm-enable --prefer-output-color-space bt2020-pq \
    #       -- ${pkgs.steam}/bin/steam -tenfoot -gamepadui
    #   '')
    #
    #   steamBpHdrDesktop
  ];

  # Gaming-specific graphics env
  environment.variables = {
    RADV_PERFTEST = "aco";
    # vblank_mode = "0";
    MESA_SHADER_CACHE_MAX_SIZE = "4G";
    mesa_glthread = "true";
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 59999 ];
    allowedUDPPorts = [ 59999 ];
  };
  # networking.firewall = {
  #   enable = true;
  #   allowedTCPPorts = [47984 47989 47990 48010];
  #   allowedUDPPortRanges = [
  #     {
  #       from = 47998;
  #       to = 48000;
  #     }
  #     #{ from = 8000; to = 8010; }
  #   ];
  # };
}
