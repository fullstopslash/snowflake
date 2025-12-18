# AI tools and services
{ lib, ... }:
{
  imports = lib.custom.autoImportModules ./.. "apps" "ai";
}
