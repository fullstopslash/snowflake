{
  inputs,
  lib,
  pkgs,
  ...
}: {
  # Minimal template for install tests: hardware, disko layout, basic services
  imports = [
    ./hardware-configuration.nix
    inputs.disko.nixosModules.disko
    ./disko-config.nix
    # SOPS for secrets and local SOPS defaults
    inputs.sops-nix.nixosModules.sops
    ../../modules/sops.nix
    ../../roles/secrets.nix
    ../../roles/universal.nix
  ];

  boot.loader = {
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 5;
    efi.canTouchEfiVariables = true;
  };

  # Minimal networking suitable for a VM
  networking.useDHCP = lib.mkDefault true;

  # SSH for post-install access
  services.openssh = {
    enable = true;
    startWhenNeeded = false;
    openFirewall = true;
  };

  # Use declarative users with SOPS-managed password
  users.mutableUsers = false;

  # Helpful in QEMU/Quickemu environments
  services.qemuGuest.enable = true;
  systemd.services."NetworkManager-wait-online".enable = false;

  # Add minimal tools for testing
  environment.systemPackages = with pkgs; [
    btop
    git
    curl
    sops
    nh
  ];

  # Enable flakes/nix-command and NH on the installed system
  nix.settings.experimental-features = ["nix-command" "flakes"];
  programs.nh.enable = true;
}
