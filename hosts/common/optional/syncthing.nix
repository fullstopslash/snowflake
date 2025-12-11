# Syncthing - continuous file synchronization
#
# Syncthing is a continuous file synchronization program. It synchronizes files
# between two or more computers in real time, safely protected from prying eyes.
#
# This module provides:
# - Syncthing daemon running as the primary user
# - Auto-configured default folder path
# - Device IDs managed via sops secrets (configured via REST API at runtime)
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
#   # Devices are auto-configured from secrets at runtime
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

    # Note: Device IDs are configured at runtime via REST API (see syncthing-configure below)
    # This avoids storing secrets in the nix store
  };

  # Configure syncthing after initialization via REST API
  # This reads device IDs from sops secrets and configures them at runtime
  systemd.services.syncthing-configure = {
    description = "Configure Syncthing devices and default folder path";
    after = [ "syncthing-init.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = username;
      RuntimeDirectory = "syncthing-configure";
    };
    script = ''
      configDir="${homeDir}/.config/syncthing"

      # Wait for config.xml to exist
      while [ ! -f "$configDir/config.xml" ]; do sleep 1; done

      # Get API key from config
      API_KEY=$(${pkgs.gnugrep}/bin/grep -oP '(?<=<apikey>)[^<]+' "$configDir/config.xml")

      # Helper function to call syncthing API
      api() {
        ${pkgs.curl}/bin/curl -sSLk -H "X-API-Key: $API_KEY" "$@" http://127.0.0.1:8384"$1"
      }

      # Set default folder path
      api "/rest/config/defaults/folder" -X PATCH \
        -H "Content-Type: application/json" \
        -d '{"path":"${homeDir}"}'

      # Read device IDs from sops secrets
      WATERBUG_ID=$(cat ${config.sops.secrets."syncthing_waterbug_id".path})
      PIXEL_ID=$(cat ${config.sops.secrets."syncthing_pixel_id".path})

      # Configure waterbug device
      api "/rest/config/devices" -X POST \
        -H "Content-Type: application/json" \
        -d "{\"deviceID\":\"$WATERBUG_ID\",\"name\":\"waterbug\",\"autoAcceptFolders\":true}"

      # Configure pixel device (as introducer)
      api "/rest/config/devices" -X POST \
        -H "Content-Type: application/json" \
        -d "{\"deviceID\":\"$PIXEL_ID\",\"name\":\"pixel\",\"autoAcceptFolders\":true,\"introducer\":true}"

      echo "Syncthing configured with devices from sops secrets"
    '';
  };
}
