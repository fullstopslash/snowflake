{ lib, ... }:
{
  imports = lib.custom.autoImportModules ./../../services "services" "networking";
}
