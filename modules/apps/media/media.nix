# Media apps module
#
# Media servers, players, and utilities.
#
# Usage: modules.apps.media = [ "media" ]
{ pkgs, ... }:
{
  # Media apps (Jellyfin, Spotify, VLC, etc)
  config = {
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
      stable.vcv-rack
      cardinal

      # Ebook management
      stable.calibre
    ];

    # Systemd user service for jellyfin-mpv-shim
    systemd.user.services.jellyfin-mpv-shim = {
      description = "Jellyfin Mpv Shim";
      documentation = [ "https://github.com/jellyfin/jellyfin-mpv-shim" ];
      after = [ "graphical-session.target" ];
      requires = [ "xdg-desktop-autostart.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.jellyfin-mpv-shim}/bin/jellyfin-mpv-shim";
        Restart = "always";
        RestartSec = "5s";
        TimeoutStartSec = "30s";
        TimeoutStopSec = "10s";
        KillMode = "mixed";
        KillSignal = "SIGTERM";
        Environment = "PATH=/run/current-system/sw/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:%h/.cargo/bin:%h/.local/share/mise/shims/";
      };
      wantedBy = [ "graphical-session.target" ];
    };
  };
}
