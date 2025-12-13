# VPN module (Mullvad)
#
# Usage: modules.services.networking = [ "vpn" ]
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.services.networking.vpn;
in
{
  options.myModules.services.networking.vpn = {
    enable = lib.mkEnableOption "Mullvad VPN";
  };

  config = lib.mkIf cfg.enable {
    services.mullvad-vpn = {
      enable = true;
      package = pkgs.mullvad-vpn;
    };
  };
}
