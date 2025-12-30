# EasyEffects systemd user service
{ pkgs, ... }:
{
  # EasyEffects systemd user service
  config = {
    environment.systemPackages = with pkgs; [
      easyeffects
      rnnoise
      rnnoise-plugin
    ];

    systemd.user.services.easyeffects = {
      description = "Easy Effects Service";
      after = [
        "graphical-session.target"
        "pipewire.service"
        "pipewire-pulse.service"
      ];
      wants = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.easyeffects}/bin/easyeffects --service-mode";
        Restart = "always";
        RestartSec = 3;
        SuccessExitStatus = "3 4";
        Environment = [
          "XDG_RUNTIME_DIR=%t"
        ];
      };
      wantedBy = [ "graphical-session.target" ];
    };
  };
}
