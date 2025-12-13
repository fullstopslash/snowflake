# Productivity and office apps
#
# Document creation, spreadsheets, presentations, diagrams.
#
# Usage:
#   myModules.apps.productivity.enable = true;
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.apps.productivity;
in
{
  options.myModules.apps.productivity = {
    enable = lib.mkEnableOption "Productivity and office apps";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Office suite
      libreoffice

      # Diagrams
      drawio
    ];
  };
}
