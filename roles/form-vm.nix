# VM role - virtual machine with full hardware and network support
#
# Minimal by default - uses empty module selections for fast builds
# Hosts can enable specific modules as needed
# Secret categories: base only
#
# NOTE: Disk config (disko) must be defined in host config, not here.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (builtins.elem "vm" config.roles) {
    # ========================================
    # MODULE SELECTIONS (minimal by default)
    # ========================================
    # VMs start minimal - hosts add what they need
    # Paths mirror filesystem: modules/<top>/<category> = [ "<module>" ]
    modules = {
      apps = {
        window-managers = [ "hyprland" ];
        desktop = [ "wayland" ];
        cli = [
          "comma"
          "shell"
          "tools-core"
        ];
      };
      services = {
        display-manager = [ "ly" ];
        cli = [ "atuin" ];
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
    boot.kernelModules = lib.mkDefault [
      "virtio-gpu"
      "bochs_drm"
    ];

    # ========================================
    # VM HARDWARE
    # ========================================
    services.xserver.videoDrivers = lib.mkDefault [ "modesetting" ];
    hardware.graphics = {
      enable = lib.mkDefault true;
      extraPackages = lib.mkDefault (with pkgs; [ mesa ]);
    };

    networking = {
      networkmanager.enable = lib.mkDefault true;
      enableIPv6 = lib.mkDefault false;
    };

    services.qemuGuest.enable = lib.mkDefault true;
    services.spice-vdagentd.enable = lib.mkDefault false;
    documentation.enable = lib.mkDefault false;

    # ========================================
    # SYSTEM CONFIGURATION
    # ========================================
    # Architecture and nixpkgs variant (VMs use unstable for testing)
    system = {
      architecture = lib.mkDefault "x86_64-linux";
      nixpkgsVariant = lib.mkDefault "unstable";
      isDarwin = lib.mkDefault false;
    };

    # Hardware defaults
    hardware.host.wifi = lib.mkDefault false;

    # Secret categories
    sops.categories = {
      base = lib.mkDefault true;
    };
  };
}
