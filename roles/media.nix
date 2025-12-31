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
    # feishin (electron-36) removed: requires insecure electron-36.9.5
    stable.vcv-rack
    cardinal
  ];

  # Spice agent for VMs
  services.spice-vdagentd.enable = true;

  # Systemd user service for jellyfin-mpv-shim
  # Uses a wrapper script that monitors output and exits on connection errors
  # This allows systemd's Restart=always to handle reconnection without polling
  systemd.user.services.jellyfin-mpv-shim = {
    description = "Jellyfin Mpv Shim";
    documentation = ["https://github.com/jellyfin/jellyfin-mpv-shim"];
    after = ["graphical-session.target"];
    requires = ["xdg-desktop-autostart.target"];
    serviceConfig = {
      Type = "simple";
      # Wrapper script that monitors jellyfin-mpv-shim output and exits on errors
      ExecStart = "${pkgs.writeShellScript "jellyfin-mpv-shim-wrapper" ''
        #!/usr/bin/env sh

        # Error patterns that indicate connection failure
        ERROR_PATTERNS="Failed to resolve|Name or service not known|Max retries exceeded|socket is closed|websocket.*error|Connection refused"

        # Run jellyfin-mpv-shim and monitor its output
        # Exit immediately if error patterns are detected
        ${pkgs.jellyfin-mpv-shim}/bin/jellyfin-mpv-shim 2>&1 | while IFS= read -r line; do
          echo "$line"
          if echo "$line" | grep -qiE "$ERROR_PATTERNS"; then
            echo "Connection error detected. Exiting to trigger restart..."
            exit 1
          fi
        done
      ''}";
      # Restart always when the wrapper exits
      Restart = "always";
      # Wait 5 seconds before restarting to allow transient issues to resolve
      RestartSec = "5s";
      TimeoutStartSec = "30s";
      TimeoutStopSec = "10s";
      KillMode = "mixed";
      KillSignal = "SIGTERM";
      Environment = "PATH=/run/current-system/sw/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:%h/.cargo/bin:%h/.local/share/mise/shims/";
    };
    wantedBy = ["graphical-session.target"];
  };

}
