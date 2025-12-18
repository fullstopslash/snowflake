{ lib, ... }:
{
  imports = lib.custom.autoImportModules ./.. "services" "audio";
}
