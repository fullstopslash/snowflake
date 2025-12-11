# Task role: VM Hardware - QEMU/KVM virtual machine hardware support
#
# Use with any hardware role to add VM-specific settings.
# Example: roles.desktop = true; roles.vmHardware = true;
#
# Provides: boot config, virtio drivers, qemu guest, VM display
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.roles;
in
{
  config = lib.mkIf cfg.vmHardware {
    #
    # ========== Boot Configuration ==========
    #
    boot.loader = {
      systemd-boot.enable = lib.mkDefault true;
      efi.canTouchEfiVariables = lib.mkDefault true;
      timeout = lib.mkDefault 3;
    };

    boot.initrd = {
      systemd.enable = lib.mkDefault true;
      kernelModules = lib.mkDefault [
        "xhci_pci"
        "ohci_pci"
        "ehci_pci"
        "virtio_pci"
        "ahci"
        "usbhid"
        "sr_mod"
        "virtio_blk"
      ];
    };

    boot.kernelParams = lib.mkDefault [
      "console=tty1"
      "console=ttyS0,115200"
    ];
    boot.kernelModules = lib.mkDefault [
      "virtio-gpu"
      "bochs_drm"
    ];

    #
    # ========== VM Display & Graphics ==========
    #
    services.xserver.videoDrivers = lib.mkDefault [ "modesetting" ];
    hardware.graphics = {
      enable = lib.mkDefault true;
      extraPackages = lib.mkDefault [ pkgs.mesa ];
    };

    #
    # ========== VM Networking ==========
    #
    networking = {
      networkmanager.enable = lib.mkDefault true;
      enableIPv6 = lib.mkDefault false;
    };

    #
    # ========== VM Guest Services ==========
    #
    services.qemuGuest.enable = lib.mkDefault true;
    services.spice-vdagentd.enable = lib.mkDefault false;
  };
}
