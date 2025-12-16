# VM Headless role - absolutely minimal virtual machine
#
# No desktop, no display manager, no GUI - just core services
# Perfect for fast-iterating test VMs
#
# NOTE: Disk config (disko) must be defined in host config, not here.
{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (builtins.elem "vmHeadless" config.roles) {
    # ========================================
    # MODULE SELECTIONS (absolutely minimal)
    # ========================================
    modules = {
      apps = {
        cli = [ "tools-core" ];
      };
      services = {
        networking = [
          "openssh"
          "ssh"
          "tailscale"
        ];
      };
    };

    # ========================================
    # BOOT CONFIGURATION
    # ========================================
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

    # ========================================
    # VM HARDWARE (minimal)
    # ========================================
    networking = {
      networkmanager.enable = lib.mkDefault true;
      enableIPv6 = lib.mkDefault false;
    };

    services.qemuGuest.enable = lib.mkDefault true;
    documentation.enable = lib.mkDefault false;

    # ========================================
    # HOSTSPEC (non-derived options only)
    # ========================================
    hostSpec = {
      isProduction = lib.mkDefault false;
      hasSecrets = lib.mkDefault true;
      wifi = lib.mkDefault false;
      isHeadless = lib.mkDefault true;

      secretCategories = {
        base = lib.mkDefault true;
      };
    };
  };
}
