# OpenRGB role
{pkgs, ...}: {
  services.hardware.openrgb.enable = true;
  environment.systemPackages = [pkgs.openrgb];
}
