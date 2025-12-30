# Firefox Browser Installation
#
# Installs Firefox browser package and configures native messaging hosts.
# Configuration (policies, extensions, settings) managed via home-manager.
#
# Usage: myModules.apps.browsers.firefox.enable = true;
{ pkgs, ... }:
{
  # Firefox browser
  config = {
    environment.systemPackages = [ pkgs.firefox ];

    programs.firefox = {
      enable = true;
      nativeMessagingHosts.packages = [
        pkgs.tridactyl-native
      ];
    };
  };
}
