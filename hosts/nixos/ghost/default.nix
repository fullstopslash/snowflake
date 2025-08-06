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
      # ========== Optional Configs ==========
      #
      "hosts/common/optional/services/greetd.nix" # display manager
      "hosts/common/optional/services/openssh.nix" # allow remote SSH access
      "hosts/common/optional/services/printing.nix" # CUPS
      "hosts/common/optional/audio.nix" # pipewire and cli controls
      "hosts/common/optional/libvirt.nix" # vm tools
      "hosts/common/optional/gaming.nix" # steam, gamescope, gamemode, and related hardware
      "hosts/common/optional/hyprland.nix" # window manager
      "hosts/common/optional/msmtp.nix" # for sending email notifications
      "hosts/common/optional/nvtop.nix" # GPU monitor (not available in home-manager)
      "hosts/common/optional/amdgpu_top.nix" # GPU monitor (not available in home-manager)
      "hosts/common/optional/obsidian.nix" # wiki
      "hosts/common/optional/plymouth.nix" # fancy boot screen
      "hosts/common/optional/protonvpn.nix" # vpn
      "hosts/common/optional/scanning.nix" # SANE and simple-scan
      "hosts/common/optional/stylix.nix" # quickrice
      "hosts/common/optional/thunar.nix" # file manager
      "hosts/common/optional/vlc.nix" # media player
      "hosts/common/optional/wayland.nix" # wayland components and pkgs not available in home-manager
      "hosts/common/optional/yubikey.nix" # yubikey related packages and configs
      "hosts/common/optional/zsa-keeb.nix" # Moonlander keeb flashing stuff

    ])
    #
    # ========== Ghost Specific ==========
    #
    ./samba.nix

  ];

  #
  # ========== Host Specification ==========
  #

  hostSpec = {
    hostName = "ghost";
    useYubikey = lib.mkForce true;
    hdr = lib.mkForce true;
    persistFolder = "/persist"; # added for "completion" because of the disko spec that was used even though impermanence isn't actually enabled here yet.
  };

  # set custom autologin options. see greetd.nix for details
  #  autoLogin.enable = true;
  #  autoLogin.username = config.hostSpec.username;
  #
  #  services.gnome.gnome-keyring.enable = true;

  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  # needed to unlock LUKS on secondary drives
  # use partition UUID
  # https://wiki.nixos.org/wiki/Full_Disk_Encryption#Unlocking_secondary_drives
  environment.etc.crypttab.text = lib.optionalString (!config.hostSpec.isMinimal) ''
    cryptextra UUID=d90345b2-6673-4f8e-a5ef-dc764958ea14 /luks-secondary-unlock.key
    cryptvms UUID=ce5f47f8-d5df-4c96-b2a8-766384780a91 /luks-secondary-unlock.key
  '';

  boot.loader = {
    systemd-boot = {
      enable = true;
      # When using plymouth, initrd can expand by a lot each time, so limit how many we keep around
      configurationLimit = lib.mkDefault 10;
    };
    efi.canTouchEfiVariables = true;
    timeout = 3;
  };

  boot.initrd = {
    systemd.enable = true;
    kernelModules = [ "amdgpu" ];
  };
  boot = {
    kernelModules = [
      "amdgpu-i2c"
    ];
    kernelPackages = pkgs.unstable.linuxPackages_latest;
    kernelParams = [
      "amdgpu.ppfeaturemask=0xfffd3fff" # https://kernel.org/doc/html/latest/gpu/amdgpu/module-parameters.html#ppfeaturemask-hexint
      "amdgpu.dcdebugmask=0x400" # Allegedly might help with some crashes
      "split_lock_detect=off" # Alleged gaming perf increase
    ];
    # Fix for XBox controller disconnects
    extraModprobeConfig = ''options bluetooth disable_ertm=1 '';
  };

  hardware = {
    #graphics.package = pkgs.unstable.mesa; # pinned in overlays
    graphics.package = pkgs.stable.mesa;
    #amdgpu.initrd.enable = true; # load amdgpu kernelModules in stage 1.
    #amdgpu.opencl.enable = true; # OpenCL support - general compute API for gpu
    #amdgpu.amdvlk.enable = true; # additional, alternative drivers
  };

  environment.systemPackages = builtins.attrValues {
    inherit (pkgs)
      clinfo # opencl testing
      vulkan-tools # vulkaninfo
      ;
  };

  #FIXME(clamav): something not working. disabled to reduce log spam
  semi-active-av.enable = false;

  services.backup = {
    enable = true;
    borgBackupStartTime = "02:00:00";
    borgServer = "${config.hostSpec.networking.subnets.grove.hosts.oops.ip}";
    borgUser = "${config.hostSpec.username}";
    borgPort = "${builtins.toString config.hostSpec.networking.ports.tcp.oops}";
    borgBackupPath = "/var/services/homes/${config.hostSpec.username}/backups";
    borgNotifyFrom = "${config.hostSpec.email.notifier}";
    borgNotifyTo = "${config.hostSpec.email.backup}";
  };

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.05";
}
