#############################################################
#
#  Ghost - Main Desktop
#  NixOS running on Ryzen 9 5900XT, Radeon RX 5700 XT, 64GB RAM
#
###############################################################

{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = lib.flatten [
    #
    # ========== Hardware ==========
    #
    ./hardware-configuration.nix
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-gpu-amd
    inputs.hardware.nixosModules.common-pc-ssd

    #
    # ========== Disk Layout ==========
    #
    inputs.disko.nixosModules.disko
    (lib.custom.relativeToRoot "hosts/common/disks/ghost.nix")

    #
    # ========== Misc Inputs ==========
    #
    inputs.stylix.nixosModules.stylix

    (map lib.custom.relativeToRoot [
      #
      # ========== Required Configs ==========
      #
      "hosts/common/core"

      #
      # ========== Host-Specific Optional Configs ==========
      # Standard desktop features come from roles.desktop
      #
      "hosts/common/optional/services/openssh.nix" # Remote SSH access
      "hosts/common/optional/services/printing.nix" # CUPS printing
      "hosts/common/optional/libvirt.nix" # VM tools
      "hosts/common/optional/msmtp.nix" # Email notifications
      "hosts/common/optional/nvtop.nix" # GPU monitor (Intel/NVIDIA)
      "hosts/common/optional/amdgpu_top.nix" # GPU monitor (AMD)
      "hosts/common/optional/obsidian.nix" # Wiki/notes
      "hosts/common/optional/protonvpn.nix" # VPN
      "hosts/common/optional/scanning.nix" # SANE scanning
      "hosts/common/optional/stylix.nix" # Theming (requires inputs.stylix)
      "hosts/common/optional/yubikey.nix" # Yubikey hardware
      "hosts/common/optional/zsa-keeb.nix" # Moonlander keyboard
    ])

    #
    # ========== Ghost-Specific ==========
    #
    ./samba.nix
  ];

  #
  # ========== Role & Host Specification ==========
  #
  roles.desktop = true;

  hostSpec = {
    hostName = "ghost";
    useYubikey = lib.mkForce true;
    hdr = lib.mkForce true;
    persistFolder = "/persist";
  };

  #
  # ========== Network ==========
  #
  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  #
  # ========== Secondary Drive Encryption ==========
  # Unlock LUKS on secondary drives using key file
  #
  environment.etc.crypttab.text = lib.optionalString (!config.hostSpec.isMinimal) ''
    cryptextra UUID=d90345b2-6673-4f8e-a5ef-dc764958ea14 /luks-secondary-unlock.key
    cryptvms UUID=ce5f47f8-d5df-4c96-b2a8-766384780a91 /luks-secondary-unlock.key
  '';

  #
  # ========== Boot Configuration ==========
  #
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = lib.mkDefault 10;
    };
    efi.canTouchEfiVariables = true;
    timeout = 3;
  };

  boot.initrd = {
    systemd.enable = true;
    kernelModules = [ "amdgpu" ];
  };

  #
  # ========== AMD GPU Configuration ==========
  #
  boot = {
    kernelModules = [ "amdgpu-i2c" ];
    kernelPackages = pkgs.unstable.linuxPackages_latest;
    kernelParams = [
      "amdgpu.ppfeaturemask=0xfffd3fff" # Enable power management features
      "amdgpu.dcdebugmask=0x400" # Crash mitigation
      "split_lock_detect=off" # Gaming performance
    ];
    # Xbox controller disconnect fix
    extraModprobeConfig = ''options bluetooth disable_ertm=1 '';
  };

  hardware.graphics.package = pkgs.unstable.mesa;

  environment.systemPackages = [ pkgs.vulkan-tools ];

  #
  # ========== Host-Specific Services ==========
  #
  semi-active-av.enable = false; # FIXME: clamav issues

  system.stateVersion = "24.05";
}
