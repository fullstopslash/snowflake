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
    # Import individually since we can't use hosts/common/core
    # (it imports stable home-manager)
    #
    (map lib.custom.relativeToRoot [
      # Module system (host-spec, roles definitions)
      "modules/common"

      # Core NixOS settings (includes nh for rebuild management)
      "hosts/common/core/nixos.nix"

      # Sops secrets (role-based categories)
      "hosts/common/core/sops"
      "hosts/common/core/ssh.nix"

      # User management (auto-imports home/rain/griefling.nix)
      "hosts/common/users"

      # Desktop services
      "hosts/common/optional/hyprland.nix"
      "hosts/common/optional/wayland.nix"
      "hosts/common/optional/services/ly.nix"
      "hosts/common/optional/tailscale.nix"
      "hosts/common/optional/services/openssh.nix"

      # Config repo auto-clone for distributed management
      "hosts/common/optional/nix-config-repo.nix"

      # Bitwarden automation
      "modules/services/security/bitwarden.nix"
    ])

    # nix-index for comma
    inputs.nix-index-database.nixosModules.nix-index
    { programs.nix-index-database.comma.enable = true; }

    # Explicitly disable display managers we don't want
    (
      { lib, ... }:
      {
        services.displayManager.sddm.enable = lib.mkForce false;
      }
    )
  ];

  #
  # ========== Host Specification ==========
  # isMinimal = false allows auto-import of home/rain/griefling.nix
  #
  hostSpec = {
    hostName = "griefling";
    primaryUsername = "rain";
    username = "rain";
    handle = "rain"; # Your handle, not emergentmind
    users = [ "rain" ];
    useWayland = true;
    useYubikey = false;
    isMinimal = false; # Allow full home-manager config import
    hasSecrets = true; # Enable sops for testing

    # Enable relevant secret categories
    secretCategories = {
      base = true; # User password, age keys
      cli = true; # CLI tool secrets (atuin, etc)
      desktop = true; # Desktop app secrets
    };

    # Inherit secrets config from inputs
    inherit (inputs.nix-secrets)
      domain
      email
      userFullName
      networking
      ;
  };

  #
  # ========== Bitwarden Automation ==========
  #
  roles.bitwardenAutomation = {
    enable = true;
    enableAutoLogin = true;
    syncInterval = 30;
  };

  #
  # ========== Config Repo Auto-Clone ==========
  # Clones nix-config and nix-secrets to ~/nix-config and ~/nix-secrets
  # for distributed config management (pull from GitHub, run nh os switch)
  #
  services.nixConfigRepo.enable = true;

  #
  # ========== Networking ==========
  #
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
  # ========== System Packages ==========
  # Only packages needed for testing core services
  #
  environment.systemPackages = with pkgs; [
    # Core utilities
    vim
    git
    curl
    rsync

    # Testing services
    tailscale
    ktailctl
    easyeffects
    kdePackages.kdeconnect-kde

    # Desktop
    ghostty # terminal
    wofi # launcher
  ];

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
  # ========== VM Display (virtio-gpu for SDL) ==========
  #
  boot.kernelParams = [
    "console=tty1"
    "console=ttyS0,115200"
  ];
  boot.kernelModules = [
    "virtio-gpu"
    "bochs_drm"
  ];

  # virtio-gpu for SDL with hardware acceleration
  services.xserver.videoDrivers = [
    "modesetting"
  ];
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      mesa
    ];
  };

  # Ensure proper TTY for LY display manager
  services.displayManager.ly.settings.tty = lib.mkForce 2; # Use tty2 to avoid conflicts

  #
  # ========== Services ==========
  #
  services.qemuGuest.enable = true;
  # Using SDL display, not SPICE
  services.spice-vdagentd.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # SSH: Enable password auth for test VM (no yubikey)
  services.openssh.settings.PasswordAuthentication = lib.mkForce true;
  services.openssh.settings.PermitRootLogin = lib.mkForce "yes";

  # Passwordless sudo for wheel group (dev VM only)
  security.sudo.wheelNeedsPassword = false;

  # Minimal docs
  documentation.enable = false;

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.11";
}
