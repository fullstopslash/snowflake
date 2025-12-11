# PipeWire audio server configuration
# Base configuration with AirPlay support and resume fix
{ pkgs, lib, ... }:
{
  services.pipewire = {
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

  # Fix audio routing after resume (restart PipeWire/WirePlumber and prefer HDMI/DP)
  systemd.services."audio-fix-after-sleep" = {
    description = "Fix PipeWire audio routing after suspend/resume";
    after = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
    ];
    wantedBy = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
    ];
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
          ${pkgs.gawk}/bin/awk 'f{if($0 ~ /^\s*[0-9]+\./){print}} /Sinks:/{f=1} /Sources:/{f=0}' |
          ${pkgs.gnugrep}/bin/grep -iE 'easy.*effects' |
          ${pkgs.gnused}/bin/sed -n 's/^\s*\([0-9]\+\)\..*/\1/p' |
          ${pkgs.coreutils}/bin/head -n1
        ) || true
        if [ -n ''${EESINK_ID:-} ]; then
          ${pkgs.wireplumber}/bin/wpctl set-default "$EESINK_ID" >/dev/null 2>&1 || true
          exit 0
        fi
        # Otherwise choose an HDMI/DP sink if present and set it as default
        SINK_ID=$(\
          ${pkgs.wireplumber}/bin/wpctl status |
          ${pkgs.gawk}/bin/awk 'f{if($0 ~ /^\s*[0-9]+\./){print}} /Sinks:/{f=1} /Sources:/{f=0}' |
          ${pkgs.gnugrep}/bin/grep -iE 'hdmi|display|monitor|dp' |
          ${pkgs.gnused}/bin/sed -n 's/^\s*\([0-9]\+\)\..*/\1/p' |
          ${pkgs.coreutils}/bin/head -n1
        ) || true
        if [ -n ''${SINK_ID:-} ]; then
          ${pkgs.wireplumber}/bin/wpctl set-default "$SINK_ID" >/dev/null 2>&1 || true
        fi
        exit 0
      ''}";
    };
  };

  # MPRIS proxy for Bluetooth media control
  systemd.user.services.mpris-proxy = {
    description = "Mpris proxy";
    after = [
      "network.target"
      "sound.target"
    ];
    wantedBy = [ "default.target" ];
    serviceConfig.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
  };
}
