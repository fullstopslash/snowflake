# Communication apps
#
# Messaging and chat applications.
#
# Usage: modules.apps.comms = [ "comms" ]
{ pkgs, ... }:
{
  # Communication apps (Discord, Slack, Signal)
  config = {
    environment.systemPackages = with pkgs; [
      discord
      slack
      unstable.signal-desktop
    ];
  };
}
