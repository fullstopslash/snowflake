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
      "modules/common/host-spec.nix" # Only host-spec, not all of modules/common
      "hosts/common/optional/hyprland.nix"
      "hosts/common/optional/services/greetd.nix"
      "hosts/common/optional/services/openssh.nix"
      "hosts/common/optional/wayland.nix"
      "hosts/common/optional/tailscale.nix"
    ])
    # Explicitly disable display managers we don't want
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
    users = [ "rain" ];
    useWayland = true;
    useYubikey = false;
    isMinimal = true;
    hasSecrets = false; # No sops secrets for test VM
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
  # ========== Nix Settings ==========
  #
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    warn-dirty = false;
  };

  #
  # ========== Basic User Setup ==========
  #
  programs.zsh.enable = true;

  users = {
    mutableUsers = false;
    allowNoPasswordLogin = true;
    users = {
      rain = {
        isNormalUser = true;
        shell = pkgs.zsh;
        extraGroups = [
          "wheel"
          "networkmanager"
        ];
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
  # MINIMAL config - no imports from home/common/core to avoid bloat
  home-manager = {
    useGlobalPkgs = true;
    backupFileExtension = "bk";
    extraSpecialArgs = {
      inherit inputs;
      hostSpec = config.hostSpec;
    };
    users.rain = {
      home = {
        username = "rain";
        homeDirectory = "/home/rain";
        stateVersion = "23.05";
      };

      # Only the packages we actually need for testing
      home.packages = with pkgs; [
        firefox
        neovim
        ktailctl
        easyeffects
        kdePackages.kdeconnect-kde
        # Basic utilities
        git
        curl
        ripgrep
      ];

      # Minimal hyprland config
      wayland.windowManager.hyprland = {
        enable = true;
        settings = {
          monitor = [ "Virtual-1,1920x1080@60,0x0,1" ];
          env = [
            "NIXOS_OZONE_WL,1"
            "XDG_SESSION_TYPE,wayland"
          ];
          exec-once = [ ];
          input = {
            follow_mouse = 2;
          };
          general = {
            gaps_in = 5;
            gaps_out = 10;
            border_size = 2;
          };
          bind = [
            "SUPER,Return,exec,ghostty"
            "SUPER,Q,killactive"
            "SUPER,M,exit"
            "SUPER,D,exec,wofi --show drun"
            "SUPER,1,workspace,1"
            "SUPER,2,workspace,2"
            "SUPER,3,workspace,3"
            "SUPER SHIFT,1,movetoworkspace,1"
            "SUPER SHIFT,2,movetoworkspace,2"
            "SUPER SHIFT,3,movetoworkspace,3"
          ];
        };
      };

      # Minimal waybar
      programs.waybar = {
        enable = true;
        settings.mainBar = {
          layer = "top";
          modules-left = [ "hyprland/workspaces" ];
          modules-center = [ "clock" ];
          modules-right = [
            "network"
            "battery"
          ];
        };
      };

      programs.home-manager.enable = true;
    };
  };

  #
  # ========== System Packages ==========
  #
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    rsync
    tailscale
    ghostty # terminal
    wofi # launcher
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
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Passwordless sudo for wheel group (dev VM only)
  security.sudo.wheelNeedsPassword = false;

  # Minimal docs
  documentation.enable = false;

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.11";
}
