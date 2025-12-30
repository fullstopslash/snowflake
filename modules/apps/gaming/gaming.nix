# Gaming apps module
#
# Gaming platforms, tools, and utilities.
#
# Usage: modules.apps.gaming = [ "gaming" ]
{ pkgs, config, ... }:
{
  # Gaming apps and utilities
  config = {
    # Steam Controller settings
    hardware.steam-hardware.enable = true;

    # Gaming programs
    programs = {
      gamemode = {
        enable = true;
      };
      gamescope = {
        enable = true;
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
          data-root = "${config.identity.home}/docker/images/";
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
      steam-run
      cataclysm-dda-git
      crawl
      crawlTiles
      brogue-ce
      stable.dwarf-fortress
      steamtinkerlaunch
      bottles
      stable.lutris
      protontricks
      protonup-qt
      nexusmods-app
      playonlinux
      winetricks
      vulkan-tools
      godot3
      SDL2
      SDL2_image
      SDL2_mixer
      SDL2_ttf
      freetype
      ncurses
      gettext
      xorg.libXcursor
      dualsensectl
      moonlight-qt
      antimicrox
      stable.starsector
      ryubing
      freeciv
      unstable.path-of-building
      usbutils
      mangohud
      mangojuice
    ];

    # Gaming-specific graphics env
    environment.variables = {
      RADV_PERFTEST = "aco";
      MESA_SHADER_CACHE_MAX_SIZE = "4G";
      mesa_glthread = "true";
    };

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 59999 ];
      allowedUDPPorts = [ 59999 ];
    };
  };
}
