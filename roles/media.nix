# Media role
{pkgs, ...}: {
  # Media packages
  environment.systemPackages = with pkgs; [
    # Media servers
    jellyfin
    jellyfin-tui

    jellyfin-web
    jellyfin-ffmpeg
    stable.jellyfin-mpv-shim
    feishin
    ffmpeg-full
    libcec

    # Media players
    vlc
    socat # for mpv-shim stuff
    mpv
    rmpc
    spotify

    streamlink
    streamlink-twitch-gui-bin
    yt-dlp

    # Effects
    easyeffects

    # Audio/Video tools
    stable.vcv-rack
    cardinal
  ];

  # Spice agent for VMs
  services.spice-vdagentd.enable = true;
}
