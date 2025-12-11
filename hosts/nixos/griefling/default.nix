#############################################################
#
#  Griefling - Test VM for Core Services
#  NixOS running on Qemu VM
#
#  Tests: bitwarden, tailscale, hyprland, waybar, ktailctl,
#         atuin, chezmoi, neovim, git/github auth, firefox
#
###############################################################

{
  inputs,
  outputs,
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = lib.flatten [
    #
    # ========== Home Manager (Unstable) ==========
    # Using unstable for newer features and nixpkgs-unstable compatibility
    # NOTE: Can't use hosts/common/core because it imports stable home-manager
    #
    inputs.home-manager-unstable.nixosModules.home-manager

    #
    # ========== Hardware ==========
    #
    ./hardware-configuration.nix

    #
    # ========== Disk Layout ==========
    #
    inputs.disko.nixosModules.disko
    (lib.custom.relativeToRoot "hosts/common/disks/btrfs-disk.nix")
    {
      _module.args = {
        disk = "/dev/vda";
        withSwap = false;
      };
    }

    #
    # ========== Core Modules ==========
    # Import individually since we can't use hosts/common/core (it imports stable home-manager)
    #
    (map lib.custom.relativeToRoot [
      # Module system (host-spec, roles definitions)
      "modules/common"

      # Core NixOS settings
      "hosts/common/core/nixos.nix"

      # Sops secrets
      "hosts/common/core/sops"
      "hosts/common/core/ssh.nix"

      # User management (auto-imports home/rain/griefling.nix)
      "hosts/common/users"

      # Desktop services (provided by roles, but need these optional ones)
      "hosts/common/optional/hyprland.nix"
      "hosts/common/optional/wayland.nix"
      "hosts/common/optional/services/ly.nix"
      "hosts/common/optional/tailscale.nix"
      "hosts/common/optional/services/openssh.nix"

      # Config repo auto-clone
      "hosts/common/optional/nix-config-repo.nix"

      # Network storage
      "hosts/common/optional/network-storage.nix"

      # Syncthing
      "hosts/common/optional/syncthing.nix"
    ])

    # nix-index for comma
    inputs.nix-index-database.nixosModules.nix-index
  ];

  # Desktop VM with development tools
  roles.desktop = true;

  hostSpec = {
    hostName = "griefling";
    # Desktop role provides: useWayland=true, isDevelopment=true, secretCategories
  };

  # Bitwarden automation for testing
  roles.bitwardenAutomation = {
    enable = true;
    enableAutoLogin = true;
    syncInterval = 30;
  };

  # Config repo auto-clone for testing
  myModules.services.nixConfigRepo.enable = true;

  # nix-index database
  programs.nix-index-database.comma.enable = true;

  #
  # ========== Home Manager Configuration ==========
  #
  home-manager = {
    useGlobalPkgs = true;
    backupFileExtension = "bk";
    extraSpecialArgs = {
      inherit inputs;
      hostSpec = config.hostSpec;
    };
  };

  #
  # ========== Overlays ==========
  #
  nixpkgs.overlays = [ outputs.overlays.default ];

  #
  # ========== Nix Settings ==========
  #
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    warn-dirty = false;
  };

  # Networking
  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  # VM-specific boot configuration
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    timeout = 3;
  };

  boot.initrd = {
    systemd.enable = true;
    kernelModules = [
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

  # VM display (virtio-gpu for SDL)
  boot.kernelParams = [
    "console=tty1"
    "console=ttyS0,115200"
  ];
  boot.kernelModules = [
    "virtio-gpu"
    "bochs_drm"
  ];

  services.xserver.videoDrivers = [ "modesetting" ];
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ mesa ];
  };

  # Ensure proper TTY for LY display manager
  services.displayManager.ly.settings.tty = lib.mkForce 2;

  # VM-specific services
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = lib.mkForce false; # Using SDL, not SPICE

  # Audio for desktop testing
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # SSH for test VM
  services.openssh.settings.PasswordAuthentication = lib.mkForce true;
  services.openssh.settings.PermitRootLogin = lib.mkForce "yes";

  # Passwordless sudo for dev VM
  security.sudo.wheelNeedsPassword = false;

  # Minimal docs for VM
  documentation.enable = false;

  # Disable unwanted display managers
  services.displayManager.sddm.enable = lib.mkForce false;

  system.stateVersion = "23.11";
}
