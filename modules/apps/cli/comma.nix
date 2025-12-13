# Comma - run programs without installing them
#
# Wraps nix-index-database's comma feature.
# Usage: , <program> - runs program from nixpkgs without installing
{ config, lib, ... }:
let
  cfg = config.myModules.apps.cli.comma;
in
{
  options.myModules.apps.cli.comma = {
    enable = lib.mkEnableOption "Comma - run programs without installing";
  };

  config = lib.mkIf cfg.enable {
    programs.nix-index-database.comma.enable = true;
  };
}
