{ lib, ... }:
{
  imports = lib.custom.autoImportModules ./.. "apps" "gaming";
}
