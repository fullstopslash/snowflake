# Security tools and applications
{ lib, ... }:
{
  imports = lib.custom.autoImportModules ./.. "apps" "security";
}
