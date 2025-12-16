# Security modules
#
# Auto-discovers and imports all security-related modules using filesystem-driven
# module discovery pattern.

{ lib, ... }:
{
  imports = lib.custom.scanPaths ./.;
}
