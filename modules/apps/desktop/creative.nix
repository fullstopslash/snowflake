# Creative and media production apps
#
# Tools for creating content: graphics, video, audio, 3D.
#
# Usage:
#   myModules.apps.desktop.creative.enable = true;
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.apps.desktop.creative;
in
{
  options.myModules.apps.desktop.creative = {
    enable = lib.mkEnableOption "Creative and media production apps";
  };

  config = lib.mkIf cfg.enable {
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
