# Syncthing - continuous file synchronization
#
# Syncthing is a continuous file synchronization program. It synchronizes files
# between two or more computers in real time, safely protected from prying eyes.
#
# This module provides:
# - Syncthing daemon running as the primary user
# - Auto-configured default folder path
# - Device IDs managed via sops secrets
# - GUI access on localhost:8384
# - Open firewall ports for discovery and sync
#
# Required secrets (in sops/shared.yaml):
#   syncthing_waterbug_id  - Device ID for waterbug
#   syncthing_pixel_id     - Device ID for pixel
#
# Usage:
#   Import this module and optionally configure devices via hostSpec:
#
#   imports = [ ./hosts/common/optional/syncthing.nix ];
#
#   # Devices are auto-configured from secrets, but can be overridden
{
  config,
  pkgs,
  ...
}:
let
  username = config.hostSpec.username;
  homeDir = config.hostSpec.home;
in
{
  # Install syncthing packages
  environment.systemPackages = with pkgs; [
    syncthing
    syncthingtray
  ];

  # Enable and configure syncthing service
  services.syncthing = {
    enable = true;
    user = username;
    group = "users";
    dataDir = homeDir;
    configDir = "${homeDir}/.config/syncthing";
    openDefaultPorts = true; # Open ports in the firewall for Syncthing

    # Device configuration with secrets
    settings = {
      devices = {
        "waterbug" = {
          id = config.sops.placeholder."syncthing_waterbug_id";
          autoAcceptFolders = true;
        };
        "pixel" = {
          id = config.sops.placeholder."syncthing_pixel_id";
          autoAcceptFolders = true;
          introducer = true;
        };
      };
    };
  };

  # Fix default folder path (NixOS module doesn't handle defaults.folder correctly)
  # This systemd service sets the default folder path to the user's home directory
  # via the Syncthing REST API after the service has initialized
  systemd.services.syncthing-default-folder-path = {
    description = "Set Syncthing default folder path";
    after = [ "syncthing-init.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = username;
      RuntimeDirectory = "syncthing-default-folder-path";
    };
    script = ''
      configDir="${homeDir}/.config/syncthing"
      # Wait for config.xml to exist
      while [ ! -f "$configDir/config.xml" ]; do sleep 1; done
      API_KEY=$(${pkgs.gnugrep}/bin/grep -oP '(?<=<apikey>)[^<]+' "$configDir/config.xml")
      ${pkgs.curl}/bin/curl -sSLk -H "X-API-Key: $API_KEY" -X PATCH \
        -H "Content-Type: application/json" \
        -d '{"path":"${homeDir}"}' \
        http://127.0.0.1:8384/rest/config/defaults/folder
    '';
  };
}
