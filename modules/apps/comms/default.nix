{ lib, ... }:
{
  imports = lib.custom.autoImportModules ./.. "apps" "comms";
}
