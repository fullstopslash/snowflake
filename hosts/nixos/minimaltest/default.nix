# Minimal desktop host demonstrating role-based inheritance
#
# This host shows the minimal configuration needed for a full desktop:
# - Pick a role (roles.desktop = true)
# - Set hostname and username
# - Provide hardware config
# - Done!
#
# Everything else comes from the desktop role:
# - Audio (pipewire)
# - Desktop environment (hyprland)
# - File manager (thunar)
# - Media player (vlc)
# - Gaming (steam)
# - Fonts, theming, etc.
#
{ lib, ... }:
{
  imports = [
    (lib.custom.relativeToRoot "hosts/common/core")
  ];

  # Just pick a role - everything else comes from inheritance
  roles.desktop = true;

  # Required: who and what
  hostSpec = {
    hostName = "minimaltest";
    primaryUsername = "rain";
  };

  # Required: hardware (minimal for evaluation)
  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };
  boot.loader.grub.device = "/dev/sda";

  system.stateVersion = "25.05";
}
