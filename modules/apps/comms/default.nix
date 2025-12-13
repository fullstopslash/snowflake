# Communication apps
#
# Messaging and chat applications.
#
# Usage:
#   myModules.apps.comms.enable = true;
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.apps.comms;
in
{
  options.myModules.apps.comms = {
    enable = lib.mkEnableOption "Communication apps (Discord, Slack, Signal)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      discord
      slack
      unstable.signal-desktop
    ];
  };
}
