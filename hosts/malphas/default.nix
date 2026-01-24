# NixOS host configuration for malphas
{
  pkgs,
  lib,
  inputs,
  ...
}: {
  # Host characteristics for conditional module behavior
  hostSpec = {
    isDesktop = true;
    hasWifi = false; # Desktop, no wifi
    primaryUser = "rain";
  };

  imports = [
    ./hardware-configuration.nix
    inputs.sops-nix.nixosModules.sops
    inputs.stylix.nixosModules.stylix
    inputs.chaotic.nixosModules.default
    ../../modules/sops.nix
    # ../../modules/hdr.nix
    # ../../roles/cachix.nix
    ../../roles/build-cache.nix
    ../../roles/desktop.nix
    # ../../roles/plasma.nix  # Temporarily disabled due to GCC15 ICE in xwayland dependency
    ../../roles/hyprland.nix
    ../../roles/greetd.nix
    ../../roles/flatpak.nix
    ../../roles/audio-tuning.nix
    ../../roles/gaming.nix
    # ../../roles/moondeck-buddy.nix
    ../../roles/development.nix
    ../../roles/media.nix
    ../../roles/obs.nix
    ../../roles/waybar.nix
    ../../roles/quickshell.nix
    ../../roles/networking.nix
    # ../../roles/sinkzone.nix
    ../../roles/vpn.nix
    ../../roles/tailscale.nix
    ../../roles/syncthing.nix
    ../../roles/syncall.nix
    ../../roles/vikunja-sync.nix
    ../../roles/vikunja-webhook.nix
    ../../roles/network-storage.nix
    ../../roles/bitwarden-automation.nix
    # ../../roles/latex.nix
    ../../roles/quickemu.nix
    ../../roles/secrets.nix
    # universal.nix now auto-applied via modules/common
    ../../roles/stylix.nix
    ../../roles/fonts.nix
    ../../roles/shell.nix
    ../../roles/atuin.nix
    ../../roles/niri.nix
    # ../../roles/voice-assistant.nix
    ../../roles/document-processing.nix
    ../../roles/cli-tools.nix
    ../../roles/ai-tools.nix
    ../../roles/containers.nix
    ../../roles/rust-packages.nix
    ../../roles/ollama.nix
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
    # kernelPackages = inputs.chaotic.legacyPackages.${pkgs.system}.linuxPackages_cachyos;
    # kernelPackages = pkgs.linuxPackages_zen;
    kernelPackages = pkgs.linuxPackages_latest;

    initrd.kernelModules = ["amdgpu"];
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

  # Build cache configuration
  roles.buildCache = {
    enable = true;
    enableBuilder = true; # This is the main build machine
    enablePush = true; # Automatically push built packages to cache
  };

  # Vikunja: bidirectional multi-project sync with instant webhook triggers
  roles.vikunjaWebhook.enable = true;
  roles.vikunjaSync.enable = true;

  # Syncall: Taskwarrior <-> CalDAV sync (Nextcloud only - Vikunja uses vikunja-sync)
  roles.syncall = {
    enable = true;
    targets = {
      nextcloud = {
        caldavUrl = "${inputs.nix-secrets.services.nextcloud.url}${inputs.nix-secrets.services.nextcloud.caldavPath}";
        caldavUser = inputs.nix-secrets.services.nextcloud.user;
        caldavCalendar = "Tasks";
        secretKey = "caldav/nextcloud";
      };
    };
  };

  # Trust Caddy's internal CA for local services (forgejo, etc.)
  security.pki.certificateFiles = [
    ../../assets/certs/caddy-root-ca.crt
  ];
}
