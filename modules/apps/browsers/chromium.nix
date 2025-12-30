# Chromium Browser Installation
#
# Installs ungoogled-chromium browser package.
# ungoogled-chromium is Chromium without Google's services and telemetry.
# Configuration (command-line args, settings) managed via home-manager.
#
# Usage: myModules.apps.browsers.chromium.enable = true;
{ pkgs, ... }:
{
  # Chromium browser (ungoogled-chromium)
  config = {
    environment.systemPackages = [ pkgs.ungoogled-chromium ];
  };
}
