# Tor module
# Usage: modules.services.networking = [ "tor" ]
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.services.networking.tor;
in
{
  options.myModules.services.networking.tor = {
    enable = lib.mkEnableOption "Tor anonymity network";
  };

  config = lib.mkIf cfg.enable {
    # Install Tor packages
    environment.systemPackages = with pkgs; [
      nyx
      tor
      torctl
      torsocks
    ];

    # Enable Tor service
    services.tor.enable = true;
  };
}
