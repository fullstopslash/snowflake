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
  # Relies on jellyfin-mpv-shim's built-in health check (health_check_interval: 300)
  # to manage connection stability. The service will restart automatically if
  # jellyfin-mpv-shim exits with an error code, which it should do when health checks fail.
  systemd.user.services.jellyfin-mpv-shim = {
    description = "Jellyfin Mpv Shim";
    documentation = ["https://github.com/jellyfin/jellyfin-mpv-shim"];
    after = ["graphical-session.target"];
    requires = ["xdg-desktop-autostart.target"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.jellyfin-mpv-shim}/bin/jellyfin-mpv-shim";
      # Restart always to handle exits - jellyfin-mpv-shim's built-in health check
      # should exit with error code on persistent socket/connection issues
      Restart = "always";
      # Wait 5 seconds before restarting to allow transient issues to resolve
      # and prevent rapid restart loops, but recover quickly
      RestartSec = "5s";
      # Set timeout for the service to be considered failed if it doesn't respond
      TimeoutStartSec = "30s";
      # Wait up to 10 seconds for graceful shutdown before force killing
      TimeoutStopSec = "10s";
      # Don't send SIGKILL immediately - give the service time to clean up
      KillMode = "mixed";
      KillSignal = "SIGTERM";
      # Keep environment clean but preserve PATH
      Environment = "PATH=/run/current-system/sw/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:%h/.cargo/bin:%h/.local/share/mise/shims/";
    };
    wantedBy = ["graphical-session.target"];
  };

  # Systemd user service for jellyfin-mpv-shim websocket watchdog (DISABLED)
  # Monitoring websocket disconnects via periodic log checks is wasteful.
  # Keeping script at ~/.config/hypr/scripts/jellyfin-websocket-watchdog.sh for reference.
  # TODO: Find a more efficient mechanism (e.g., systemd path unit, journald triggers, etc.)
  # systemd.user.services.jellyfin-mpv-shim-websocket-watchdog = {
  #   description = "Jellyfin MPV Shim Websocket Watchdog";
  #   after = ["graphical-session.target"];
  #   serviceConfig = {
  #     Type = "oneshot";
  #     ExecStart = "${pkgs.writeShellScript "jellyfin-websocket-watchdog" ''
  #       #!/usr/bin/env sh
  #       SERVICE="jellyfin-mpv-shim"
  #       LOG_PATTERNS="socket is closed|websocket.*error|websocket.*closed"
  #       LOOKBACK_SECONDS=3
  #
  #       # Check for websocket errors in recent logs
  #       if journalctl --user -u "$SERVICE" --since "''${LOOKBACK_SECONDS} seconds ago" --no-pager 2>/dev/null | \
  #          grep -qiE "$LOG_PATTERNS"; then
  #         # Websocket disconnected - restart service to trigger reconnect
  #         systemctl --user restart "$SERVICE" 2>/dev/null || exit 1
  #       fi
  #     ''}";
  #     Environment = "PATH=/run/current-system/sw/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:%h/.cargo/bin:%h/.local/share/mise/shims/";
  #   };
  # };
  #
  # systemd.user.timers.jellyfin-mpv-shim-websocket-watchdog = {
  #   description = "Jellyfin MPV Shim Websocket Watchdog Timer";
  #   wantedBy = ["timers.target"];
  #   timerConfig = {
  #     OnActiveSec = "5s";
  #     OnUnitActiveSec = "5s";
  #     AccuracySec = "1s";
  #   };
  # };
}
