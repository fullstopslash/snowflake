{
  inputs,
  lib,
  ...
}: {
  # Minimal template for install tests: hardware, disko layout, basic services
  imports = [
    ./hardware-configuration.nix
    inputs.disko.nixosModules.disko
    ./disko-config.nix
  ];

  system.stateVersion = "24.11";

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

  # Helpful in QEMU/Quickemu environments
  services.qemuGuest.enable = true;
  systemd.services."NetworkManager-wait-online".enable = false;
}
