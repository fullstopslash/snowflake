{ lib, ... }:
{
  imports = lib.custom.autoImportModules ./.. "apps" "cli";
}
