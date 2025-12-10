# Syncthing role
{
  config,
  pkgs,
  ...
}: let
  username = config.hostSpec.primaryUser;
  homeDir = config.users.users.${username}.home;
in {
  # Syncthing packages
  environment.systemPackages = with pkgs; [
    # Syncthing tools
    syncthing
    syncthingtray
  ];

  # Syncthing service
  services.syncthing = {
    enable = true;
    user = username;
    group = "users";
    dataDir = homeDir;
    configDir = "${homeDir}/.config/syncthing";
    openDefaultPorts = true; # Open ports in the firewall for Syncthing
    settings = {
      devices = {
        "waterbug" = {
          id = "J3DXCSN-BGNTR5F-BTMQTO3-TKAMOAI-YUBTL6B-773ZK2S-CKTDRLQ-U53DOQO";
          autoAcceptFolders = true;
        };
        "pixel" = {
          id = "76GJOGY-N4RH7MP-VAZDXE3-ZXSCHRC-ARVHWY5-J4FUAL7-US26ZAU-Z5PJTQV";
          autoAcceptFolders = true;
          introducer = true;
        };
      };
    };
  };

  # Fix default folder path (NixOS module doesn't handle defaults.folder correctly)
  systemd.services.syncthing-default-folder-path = {
    description = "Set Syncthing default folder path";
    after = ["syncthing-init.service"];
    wantedBy = ["multi-user.target"];
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
