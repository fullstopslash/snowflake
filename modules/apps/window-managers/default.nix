{ lib, ... }:
{
  imports = lib.custom.autoImportModules ./.. "apps" "window-managers";
}
