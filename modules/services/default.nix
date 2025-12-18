# Service modules
#
# Auto-discovers and imports all service modules using filesystem-driven
# module discovery pattern.

{ lib, ... }:
{
  imports = lib.custom.scanPaths ./.;
}
