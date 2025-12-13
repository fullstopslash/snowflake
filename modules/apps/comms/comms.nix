# Communication apps
#
# Messaging and chat applications.
#
# Usage: modules.apps.comms = [ "comms" ]
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.apps.comms.comms;
in
{
  options.myModules.apps.comms.comms = {
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
