# Audio tuning role (low-latency PipeWire + rtkit)
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    pwvucontrol
    # helvum
    qpwgraph
    playerctl
    easyeffects
    rnnoise
    rnnoise-plugin
  ];
  security.rtkit.enable = true;

  services.pipewire.extraConfig.pipewire."92-low-latency" = {
    "context.properties" = {
      "default.clock.rate" = 48000;
      "default.clock.quantum" = 256;
      "default.clock.min-quantum" = 256;
      "default.clock.max-quantum" = 256;
    };
  };

  services.pipewire.extraConfig.pipewire-pulse."92-low-latency" = {
    "context.properties" = [
      {
        name = "libpipewire-module-protocol-pulse";
        args = {};
      }
    ];
    "pulse.properties" = {
      "pulse.min.req" = "256/48000";
      "pulse.default.req" = "256/48000";
      "pulse.max.req" = "256/48000";
      "pulse.min.quantum" = "256/48000";
      "pulse.max.quantum" = "256/48000";
    };
    "stream.properties" = {
      "node.latency" = "256/48000";
      "resample.quality" = 1;
    };
  };

  # EasyEffects systemd user service
  systemd.user.services.easyeffects = {
    description = "Easy Effects Service";
    after = ["graphical-session.target" "pipewire.service" "pipewire-pulse.service"];
    wants = ["graphical-session.target"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.easyeffects}/bin/easyeffects --gapplication-service";
      Restart = "always";
      RestartSec = 3;
      SuccessExitStatus = "3 4";
      Environment = [
        "XDG_RUNTIME_DIR=%t"
      ];
    };
    wantedBy = ["graphical-session.target"];
  };
}
