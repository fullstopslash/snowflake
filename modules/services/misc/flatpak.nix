# Flatpak module
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.services.misc.flatpak;
in
{
  options.myModules.services.misc.flatpak = {
    enable = lib.mkEnableOption "Flatpak support";
  };

  config = lib.mkIf cfg.enable {
    services.flatpak.enable = true;

    # Flatpak systemd service
    systemd.services.flatpak-repo = {
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.flatpak ];
      script = ''
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
      '';
      serviceConfig = {
        TimeoutStartSec = "30";
        Restart = "on-failure";
      };
    };
  };
}
