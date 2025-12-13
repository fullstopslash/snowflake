# Audio tools and rtkit
{ config, pkgs, lib, ... }:
let
  cfg = config.myModules.services.audio.tools;
in
{
  options.myModules.services.audio.tools = {
    enable = lib.mkEnableOption "audio tools and rtkit";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      pwvucontrol
      qpwgraph
      playerctl
      easyeffects
      rnnoise
      rnnoise-plugin
    ];

    security.rtkit.enable = true;
  };
}
