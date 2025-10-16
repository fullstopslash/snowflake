{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Quickemu/QEMU-friendly initrd modules (virtio for vda)
  boot = {
    initrd = {
      availableKernelModules = [
        "virtio_pci"
        "virtio_blk"
        "virtio_scsi"
        "xhci_pci"
        "usbhid"
        "sd_mod"
        "ahci"
      ];
      kernelModules = [];
    };
    kernelModules = [];
  };

  # Disk layout and mounts are managed by disko in the template default.nix

  # Enable DHCP on each ethernet and wireless interface
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Hardware configuration (customize as needed)
  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;
    firmware = with pkgs; [linux-firmware];
  };
}
