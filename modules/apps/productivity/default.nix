{ lib, ... }:
{
  imports = lib.custom.autoImportModules ./.. "apps" "productivity";
}
