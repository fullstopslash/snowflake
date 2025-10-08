#############################################################
#
#  Malphas - Migrated minimal host
#  Starts minimal and uses fixture secrets; replace later with real sops
#
###############################################################
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = lib.flatten [
    # Hardware
    ./hardware-configuration.nix

    # Common core (brings home-manager, sops, nix-index, users, etc.)
    (lib.custom.relativeToRoot "hosts/common/core")
  ];

  # Host spec
  hostSpec = {
    hostName = "malphas";
    primaryUsername = "rain";
    username = "rain";
  };

  # Use the bundled fixture secrets file until real sops files are added
  # Replace with inputs.nix-secrets path after creating /sops/malphas.yaml
  sops.defaultSopsFile = inputs.self + "/tests/fixtures/nix-secrets/sops.yaml";

  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  # Enable SSH server for remote access
  services.openssh = {
    enable = true;
    ports = [ 22 ];
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    timeout = 3;
  };

  boot.initrd.systemd.enable = true;

  # Set explicitly during migration; upstream modules usually manage this
  system.stateVersion = "25.05";
}







