#############################################################
#
#  Griefling - Minimal Test VM with Hyprland
#  NixOS running on Qemu VM
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
    (map lib.custom.relativeToRoot [
      #
      # ========== Minimal Configs ==========
      #
      # Don't import hosts/common/core - it pulls in all roles
      # Instead, import only what's needed
      "modules/common" # Shared modules
      "hosts/common/core/sops" # Secrets management
      "hosts/common/optional/hyprland.nix"
      "hosts/common/optional/services/greetd.nix"
      "hosts/common/optional/services/openssh.nix"
      "hosts/common/optional/wayland.nix"
      "hosts/common/optional/tailscale.nix"
    ])
    # Explicitly disable ly and sddm for this host
    (
      { lib, ... }:
      {
        services.displayManager.ly.enable = lib.mkForce false;
        services.displayManager.sddm.enable = lib.mkForce false;
      }
    )
  ];

  #
  # ========== Host Specification ==========
  #
  hostSpec = {
    hostName = "griefling";
    primaryUsername = "rain";
    username = "rain";
    users = [ "rain" ]; # Required for user creation
    useWayland = true;
    useYubikey = false; # No yubikey in test VM
    isMinimal = true; # Mark as minimal to avoid pulling in extras
    # Inherit secrets config from inputs
    inherit (inputs.nix-secrets)
      domain
      email
      userFullName
      networking
      ;
  };

  networking = {
    hostName = config.hostSpec.hostName;
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  #
  # ========== Basic User Setup ==========
  #
  programs.zsh.enable = true;
  programs.git.enable = true;

  users = {
    mutableUsers = false;
    # Allow no password login for dev VM
    allowNoPasswordLogin = true;
    users = {
      rain = {
        isNormalUser = true;
        shell = pkgs.zsh;
        extraGroups = [
          "wheel"
          "networkmanager"
        ];
        # Dev VM: No password
        hashedPassword = null;
      };
      root = {
        shell = pkgs.zsh;
        hashedPassword = null;
      };
    };
  };

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
    users.rain = {
      imports = [
        (lib.custom.relativeToRoot "home/common/core")
        (lib.custom.relativeToRoot "home/common/core/nixos.nix")
        (lib.custom.relativeToRoot "home/common/optional/desktops/hyprland")
        (lib.custom.relativeToRoot "home/common/optional/desktops/waybar.nix")
      ];

      home = {
        username = "rain";
        homeDirectory = "/home/rain";
        stateVersion = "23.05";
      };

      # Minimal packages for testing
      home.packages = with pkgs; [
        firefox
        neovim
        ktailctl
        easyeffects
        kdePackages.kdeconnect-kde
      ];

      # Monitor config for VM
      monitors = [
        {
          name = "Virtual-1";
          primary = true;
          width = 1920;
          height = 1080;
          refreshRate = 60;
          x = 0;
          y = 0;
          enabled = true;
        }
      ];

      wayland.windowManager.hyprland.enable = true;
    };
  };

  #
  # ========== System Packages ==========
  #
  environment.systemPackages = with pkgs; [
    just
    rsync
    openssh
    tailscale
  ];

  #
  # ========== Overlays ==========
  #
  nixpkgs = {
    overlays = [ outputs.overlays.default ];
    config = {
      allowUnfree = true;
      allowBroken = true;
    };
  };

  #
  # ========== Boot Configuration ==========
  #
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

  #
  # ========== Services ==========
  #
  # VM guest tools
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  # Enable VSCode remote SSH
  programs.nix-ld.enable = true;

  # Passwordless sudo for wheel group (dev VM only)
  security.sudo.wheelNeedsPassword = false;

  # Minimal docs
  documentation.enable = false;

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.11";
}
