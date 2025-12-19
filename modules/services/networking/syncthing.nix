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
  username = config.host.username;
  homeDir = config.host.home;
in
{
  description = "Syncthing file synchronization";

  config = {
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
      after = [
        "syncthing-init.service"
        "syncthing.service"
      ];
      wants = [ "syncthing.service" ];
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
          timeout=30
          elapsed=0
          while [ ! -f "$configDir/config.xml" ] && [ $elapsed -lt $timeout ]; do
            sleep 1
            elapsed=$((elapsed + 1))
          done

          if [ ! -f "$configDir/config.xml" ]; then
            echo "Timeout waiting for Syncthing config.xml" 1>&2
            exit 1
          fi

          # Get API key from config
          API_KEY=$(${pkgs.gnugrep}/bin/grep -oP '(?<=<apikey>)[^<]+' "$configDir/config.xml")

          # Wait for Syncthing API to be ready with retries
          max_retries=30
          retry=0
          while [ $retry -lt $max_retries ]; do
            if ${pkgs.curl}/bin/curl -sSf -H "X-API-Key: $API_KEY" \
              "http://127.0.0.1:8384/rest/system/status" >/dev/null 2>&1; then
              break
            fi
            retry=$((retry + 1))
            echo "Waiting for Syncthing API (attempt $retry/$max_retries)..." 1>&2
            sleep 1
          done

          if [ $retry -eq $max_retries ]; then
            echo "Timeout waiting for Syncthing API to be ready" 1>&2
            exit 1
          fi

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
