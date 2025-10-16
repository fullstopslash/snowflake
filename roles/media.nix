# Media role
{pkgs, ...}: {
  # Media packages
  environment.systemPackages = with pkgs; [
    # Media servers
    jellyfin
    jellyfin-tui
    jftui
    jellycli

    jellyfin-web
    jellyfin-ffmpeg
    jellyfin-mpv-shim
    feishin
    ffmpeg-full
    stable.libcec

    # Media players
    vlc
    socat # for mpv-shim stuff
    mpv
    mpd
    mpd-mpris
    mpd-sima
    rmpc
    stable.spotify

    streamlink
    streamlink-twitch-gui-bin
    yt-dlp

    # Effects
    easyeffects

    # Audio/Video tools
    # stable.vcv-rack
    cardinal
  ];

  # Spice agent for VMs
  services.spice-vdagentd.enable = true;
}
