# VPN role (Mullvad)
{ pkgs, ... }:
{
  services.mullvad-vpn = {
    enable = false;
    package = pkgs.mullvad-vpn;
  };
}
