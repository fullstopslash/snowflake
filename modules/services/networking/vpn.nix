# VPN module (Mullvad)
#
# Usage: modules.services.networking = [ "vpn" ]
{
  pkgs,
  ...
}:
{
  description = "Mullvad VPN";

  config = {
    services.mullvad-vpn = {
      enable = true;
      package = pkgs.mullvad-vpn;
    };
  };
}
