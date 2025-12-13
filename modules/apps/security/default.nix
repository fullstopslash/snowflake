# Security tools and applications
{ lib, ... }:
{
  imports = lib.custom.scanPaths ./.;
}
