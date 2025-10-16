# Syncthing role
{pkgs, ...}: {
  # Syncthing packages
  environment.systemPackages = with pkgs; [
    # Syncthing tools
    syncthing
    syncthingtray
  ];

  # Syncthing service
  services.syncthing = {
    enable = true;
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
}
