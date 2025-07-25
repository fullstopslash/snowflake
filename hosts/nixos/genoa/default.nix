#############################################################
#
#  Genoa - Laptop
#  NixOS running on Lenovo Thinkpad E15
#
###############################################################

{
  inputs,
  lib,
  ...
}:
{
  imports = lib.flatten [
    #
    # ========== Hardware ==========
    #

    inputs.hardware.nixosModules.lenovo-thinkpad-e15-intel
    ./hardware-configuration.nix

    #
    # ========== Disk Layout ==========
    #
    inputs.disko.nixosModules.disko
    (lib.custom.relativeToRoot "hosts/common/disks/btrfs-luks-impermanence-disk.nix")
    {
      _module.args = {
        disk = "/dev/nvme0n1";
        withSwap = true;
        swapSize = 16;
      };
    }

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
      "hosts/common/optional/services/bluetooth.nix" # bluetooth, blueman and bluez via wireplumber
      "hosts/common/optional/services/greetd.nix" # display manager
      "hosts/common/optional/services/openssh.nix" # allow remote SSH access
      "hosts/common/optional/services/printing.nix" # CUPS
      "hosts/common/optional/audio.nix" # pipewire and cli controls
      "hosts/common/optional/gaming.nix" # window manager
      "hosts/common/optional/hyprland.nix" # window manager
      "hosts/common/optional/nvtop.nix" # GPU monitor (not available in home-manager)
      "hosts/common/optional/obsidian.nix" # wiki
      "hosts/common/optional/plymouth.nix" # fancy boot screen
      "hosts/common/optional/protonvpn.nix" # vpn
      "hosts/common/optional/stylix.nix" # quickrice
      "hosts/common/optional/thunar.nix" # file manager
      "hosts/common/optional/vlc.nix" # media player
      "hosts/common/optional/wayland.nix" # wayland components and pkgs not available in home-manager
      "hosts/common/optional/wifi.nix" # wayland components and pkgs not available in home-manager
      "hosts/common/optional/yubikey.nix" # yubikey related packages and configs
    ])
  ];

  #
  # ========== Host Specification ==========
  #

  hostSpec = {
    hostName = "genoa";
    isMobile = lib.mkForce true;
    useYubikey = lib.mkForce true;
    hdr = lib.mkForce true;
    wifi = lib.mkForce true;
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

  #Firmwareupdate
  #  $ fwupdmgr update
  services.fwupd.enable = true;

  #  services.backup = {
  #    enable = true;
  #    borgBackupStartTime = "02:00:00";
  #    borgServer = "${config.hostSpec.networking.subnets.grove.hosts.oops.ip}";
  #    borgUser = "${config.hostSpec.username}";
  #    borgPort = "${builtins.toString config.hostSpec.networking.ports.tcp.oops}";
  #    borgBackupPath = "/var/services/homes/${config.hostSpec.username}/backups";
  #    borgNotifyFrom = "${config.hostSpec.email.notifier}";
  #    borgNotifyTo = "${config.hostSpec.email.backup}";
  #  };

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
  };

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.05";
}
