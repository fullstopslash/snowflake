{ lib, ... }:
{
  imports = lib.custom.autoImportModules ./.. "apps" "desktop";
}
