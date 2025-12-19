# CLI services module - auto-imports all modules in this directory
{ lib, ... }:
{
  imports = lib.custom.autoImportModules ./.. "services" "cli";
}
