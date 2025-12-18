# Creative and media production apps
#
# Tools for creating content: graphics, video, audio, 3D.
#
# Usage:
#   myModules.apps.desktop.creative.enable = true;
{ pkgs, ... }:
{
  description = "Creative and media production apps";
  config = {
    environment.systemPackages = with pkgs; [
      # Graphics
      gimp
      inkscape

      # 3D
      blender-hip # -hip variant includes h/w accelerated rendering with AMD RDNA GPUs

      # Audio
      audacity

      # Video/Streaming
      obs-studio
    ];
  };
}
