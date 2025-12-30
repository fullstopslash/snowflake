# Tor module
# Usage: modules.services.networking = [ "tor" ]
{
  pkgs,
  ...
}:
{
  # Tor anonymity network

  config = {
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
