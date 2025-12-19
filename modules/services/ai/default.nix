{ lib, ... }:
{
  imports = lib.custom.autoImportModules ./.. "services" "ai";
}
