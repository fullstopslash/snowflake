# Audio tools
{ pkgs, ... }:
{
  # audio tools and rtkit
  config = {
    environment.systemPackages = with pkgs; [
      pwvucontrol
      qpwgraph
      playerctl
    ];
  };
}
