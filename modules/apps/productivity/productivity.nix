# Productivity and office apps
#
# Document creation, spreadsheets, presentations, diagrams.
#
# Usage: modules.apps.productivity = [ "productivity" ]
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.apps.productivity.productivity;
in
{
  options.myModules.apps.productivity.productivity = {
    enable = lib.mkEnableOption "Productivity and office apps";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      libreoffice
      drawio
    ];
  };
}
