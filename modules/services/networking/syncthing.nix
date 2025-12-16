# Syncthing - continuous file synchronization
#
# Syncthing is a continuous file synchronization program. It synchronizes files
# between two or more computers in real time, safely protected from prying eyes.
#
# This module provides:
# - Syncthing daemon running as the primary user
# - Auto-configured default folder path
# - Device IDs from nix-secrets flake (configured via REST API at runtime)
# - GUI access on localhost:8384
# - Open firewall ports for discovery and sync
#
# Device IDs are sourced from: inputs.nix-secrets.syncthing
#
# Usage:
#   myModules.services.syncthing.enable = true;
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.myModules.services.networking.syncthing;
  username = config.host.username;
  homeDir = config.host.home;
in
{
  options.myModules.services.networking.syncthing = {
    enable = lib.mkEnableOption "Syncthing file synchronization";
  };

  config = lib.mkIf cfg.enable {
    # Install syncthing packages
    environment.systemPackages =
      with pkgs;
      [
        syncthing
      ]
      ++ lib.optionals (!config.host.isHeadless or false) [
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
    # This uses device IDs from nix-secrets flake and configures them at runtime
    systemd.services.syncthing-configure = {
      description = "Configure Syncthing devices and default folder path";
      after = [ "syncthing-init.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = username;
        RuntimeDirectory = "syncthing-configure";
      };
      script =
        let
          syncthingSecrets = inputs.nix-secrets.syncthing;
        in
        ''
          configDir="${homeDir}/.config/syncthing"

          # Wait for config.xml to exist
          while [ ! -f "$configDir/config.xml" ]; do sleep 1; done

          # Get API key from config
          API_KEY=$(${pkgs.gnugrep}/bin/grep -oP '(?<=<apikey>)[^<]+' "$configDir/config.xml")

          # Set default folder path
          ${pkgs.curl}/bin/curl -sSLk -H "X-API-Key: $API_KEY" -X PATCH \
            -H "Content-Type: application/json" \
            -d '{"path":"${homeDir}"}' \
            "http://127.0.0.1:8384/rest/config/defaults/folder"

          # Configure waterbug device
          ${pkgs.curl}/bin/curl -sSLk -H "X-API-Key: $API_KEY" -X POST \
            -H "Content-Type: application/json" \
            -d '{"deviceID":"${syncthingSecrets.waterbug}","name":"waterbug","autoAcceptFolders":true}' \
            "http://127.0.0.1:8384/rest/config/devices"

          # Configure pixel device (as introducer)
          ${pkgs.curl}/bin/curl -sSLk -H "X-API-Key: $API_KEY" -X POST \
            -H "Content-Type: application/json" \
            -d '{"deviceID":"${syncthingSecrets.pixel}","name":"pixel","autoAcceptFolders":true,"introducer":true}' \
            "http://127.0.0.1:8384/rest/config/devices"

          echo "Syncthing configured with devices from nix-secrets"
        '';
    };
  };
}
