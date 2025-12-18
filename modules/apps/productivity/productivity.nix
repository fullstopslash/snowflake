# Productivity and office apps
#
# Document creation, spreadsheets, presentations, diagrams.
#
# Usage: modules.apps.productivity = [ "productivity" ]
{ pkgs, ... }:
{
  description = "Productivity and office apps";
  config = {
    environment.systemPackages = with pkgs; [
      libreoffice
      drawio
    ];
  };
}
