{ lib, ... }:
{
  imports = lib.custom.autoImportModules ./.. "apps" "browsers";
}
