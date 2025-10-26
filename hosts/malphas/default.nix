# NixOS host configuration for malphus
{
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    inputs.sops-nix.nixosModules.sops
    inputs.stylix.nixosModules.stylix
    ../../modules/sops.nix
    # ../../modules/hdr.nix
    # ../../roles/cachix.nix
    ../../roles/desktop.nix
    # ../../roles/plasma.nix  # Temporarily disabled due to GCC15 ICE in xwayland dependency
    ../../roles/hyprland.nix
    ../../roles/greetd.nix
    ../../roles/flatpak.nix
    ../../roles/audio-tuning.nix
    ../../roles/gaming.nix
    # ../../roles/moondeck-buddy.nix
    ../../roles/development.nix
    ../../roles/crush.nix
    ../../roles/media.nix
    ../../roles/obs.nix
    ../../roles/waybar.nix
    ../../roles/networking.nix
    # ../../roles/vpn.nix
    ../../roles/tailscale.nix
    ../../roles/syncthing.nix
    ../../roles/network-storage.nix
    ../../roles/bitwarden-automation.nix
    # ../../roles/latex.nix
    ../../roles/quickemu.nix
    ../../roles/secrets.nix
    ../../roles/universal.nix
    ../../roles/stylix.nix
    ../../roles/fonts.nix
    ../../roles/shell.nix
    ../../roles/atuin.nix
    ../../roles/niri.nix
    # ../../roles/voice-assistant.nix
    # ../../roles/document-processing.nix
    ../../roles/cli-tools.nix
    ../../roles/ai-tools.nix
    ../../roles/containers.nix
    ../../roles/rust-packages.nix
    # ../../roles/ollama.nix  # enable when ready
    # ../../modules/hdr.nix
    ../../modules/ssh-no-sleep.nix
  ];

  # Host-specific configuration
  # Hostname is set by the flake.nix mkHost function

  # System-specific settings

  # Hardware-specific settings
  hardware.system76.enableAll = true;

  # Boot configuration
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 8;
      };
      efi.canTouchEfiVariables = true;
    };
    plymouth = {
      enable = false;
      theme = "bgrt";
      themePackages = [pkgs.nixos-bgrt-plymouth];
    };

    kernelParams = [
      "quiet"
      "splash"
      "systemd.show_status=0"
      "rd.systemd.show_status=0"
      "amd_pstate=active"
      "transparent_hugepage=madvise"
    ];
    # boot.kernelPackages = pkgs.linuxPackages_cachyos;
    # kernelPackages = pkgs.linuxPackages_zen;
    kernelPackages = pkgs.linuxPackages_latest;

    initrd.kernelModules = ["amdgpu"];
    kernel.sysctl = {
      "net.ipv4.conf.all.forwarding" = true;
      "net.ipv6.conf.all.forwarding" = true;
      # Accept IPv6 Router Advertisements even when forwarding is enabled
      "net.ipv6.conf.all.accept_ra" = 2;
      "net.ipv6.conf.default.accept_ra" = 2;
    };
  };

  users.mutableUsers = false;
  # SOPS configuration - using default from modules/sops.nix
  # No need to override sops.age.keyFile as it's set in the module

  # Stylix theming
  roles.stylix = {
    enable = true;
    theme = "catppuccin-mocha";
    wallpaper = ../../assets/this.webp;
    cursorTheme = "Nordzy-catppuccin-mocha-dark"; # Vector-based cursor with Catppuccin Mocha colors
    cursorSize = 24;
  };

  # Fix Qt platform theme for KDE6 compatibility
  qt.platformTheme = lib.mkForce "kde";

  # Bitwarden automation configuration
  roles.bitwardenAutomation = {
    enable = true;
    enableAutoLogin = true;
    syncInterval = 30;
  };

  # Explicit networking preferences for this host
  networking = {
    # Ensure IPv6 is enabled
    enableIPv6 = true;
    # Use local DNS server directly instead of router DNS
    nameservers = [
      "192.168.86.82"
    ];
  };

  # Prefer public fallbacks in systemd-resolved (primary set via networking.nameservers)
  services.resolved.fallbackDns = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  # Force systemd-resolved to use the LAN DNS for all lookups by default
  # This prevents DHCP-provided DNS from taking precedence
  services.resolved.extraConfig = ''
    [Resolve]
    DNS=192.168.86.82
    Domains=~.
  '';
}
