# VM role - virtual machine with full hardware and network support
#
# Enables: QEMU guest tools, virtio drivers, VM display, networking
# Provides: Boot configuration, kernel modules, video drivers
# Optional: Desktop services (hyprland, wayland), networking (tailscale, openssh)
# Sets: VM-optimized boot, kernel parameters, display drivers
# Secret categories: base only
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
  # Virtual machine - full VM support
  imports = [
    ../modules/apps/cli
    ../hosts/common/optional/hyprland.nix
    ../hosts/common/optional/wayland.nix
    ../hosts/common/optional/tailscale.nix
    ../hosts/common/optional/services/openssh.nix
  ];

  # VM-specific config
  config = lib.mkIf cfg.vm {
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
      # VM-specific kernel modules for virtio and USB
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

    # Console output for VM (serial and TTY)
    boot.kernelParams = lib.mkDefault [
      "console=tty1"
      "console=ttyS0,115200"
    ];

    # VM display drivers (virtio-gpu for SDL, bochs for fallback)
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
      extraPackages = lib.mkDefault (with pkgs; [ mesa ]);
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
    # SPICE disabled by default (use SDL), hosts can enable with lib.mkForce
    services.spice-vdagentd.enable = lib.mkDefault false;

    #
    # ========== Minimal Configuration ==========
    #
    documentation.enable = lib.mkDefault false;

    #
    # ========== VM hostSpec defaults ==========
    # Hosts can override with lib.mkForce
    #
    hostSpec = {
      # Behavioral defaults specific to VM
      isMinimal = lib.mkDefault true; # VMs are minimal by default
      isProduction = lib.mkDefault false; # VMs are for testing
      hasSecrets = lib.mkDefault false; # VMs typically don't have secrets
      useWayland = lib.mkDefault false; # Minimal VMs don't use Wayland
      useWindowManager = lib.mkDefault false; # Minimal VMs are headless
      isDevelopment = lib.mkDefault false; # Not a dev workstation
      isMobile = lib.mkDefault false; # VMs are not mobile
      wifi = lib.mkDefault false; # VMs use virtual networking

      # VM secret categories (minimal - hosts can override if needed)
      secretCategories = {
        base = lib.mkDefault false; # VMs typically don't have secrets
      };
    };
  };
}
