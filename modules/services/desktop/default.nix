{ lib, ... }:
{
  imports = lib.custom.autoImportModules ./.. "services" "desktop";
}
