{ lib, ... }:
{
  # System modules - creates myModules.system namespace
  imports = lib.custom.scanPaths ./.;

  # Create the myModules.system namespace for system-level modules
  options.myModules.system = lib.mkOption {
    type = lib.types.submodule { };
    default = { };
    description = "System-level module options";
  };
}
