# EasyEffects systemd user service
{ config, pkgs, lib, ... }:
let
  cfg = config.myModules.services.audio.easyeffects;
in
{
  options.myModules.services.audio.easyeffects = {
    enable = lib.mkEnableOption "EasyEffects systemd user service";
  };

  config = lib.mkIf cfg.enable {
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
