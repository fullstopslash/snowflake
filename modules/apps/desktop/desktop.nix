# Desktop utilities and tools
#
# General desktop utilities that aren't media, gaming, or productivity specific.
#
# Usage: modules.apps.desktop = [ "desktop" ]
{ pkgs, ... }:
{
  # Desktop utilities and tools
  config = {
    environment.systemPackages = with pkgs; [
      grimblast
      rpi-imager

      # Essential desktop utilities (moved from home-manager)
      pulseaudio # add pulse audio to the user path
      pavucontrol # gui for pulseaudio server and volume controls
      wl-clipboard # wayland copy and paste
      galculator # gtk based calculator
    ];
  };
}
