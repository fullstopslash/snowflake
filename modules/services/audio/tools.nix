# Audio tools
{ pkgs, ... }:
{
  description = "audio tools and rtkit";
  config = {
    environment.systemPackages = with pkgs; [
      pwvucontrol
      qpwgraph
      playerctl
    ];
  };
}
