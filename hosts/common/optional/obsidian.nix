{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.unstable.obsidian ];
}
