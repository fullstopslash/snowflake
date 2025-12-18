# Application modules
#
# Auto-discovers and imports all application modules using filesystem-driven
# module discovery pattern.

{ lib, ... }:
{
  imports = lib.custom.scanPaths ./.;
}
