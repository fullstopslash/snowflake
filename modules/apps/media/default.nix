{ lib, ... }:
{
  imports = lib.custom.autoImportModules ./.. "apps" "media";
}
