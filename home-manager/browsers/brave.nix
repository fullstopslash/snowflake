# Brave configuration via home-manager programs.brave
# Package installation via: myModules.apps.browsers.brave.enable = true
# Both must be enabled for Brave to work with these settings
{ pkgs, ... }:
{
  programs.brave = {
    enable = true;
    package = pkgs.unstable.brave;
    commandLineArgs = [
      "--no-default-browser-check"
      "--restore-last-session"
    ];
  };
}
