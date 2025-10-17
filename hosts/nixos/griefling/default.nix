#############################################################
#
#  Griefling - Dev Lab with Hyprland
#  NixOS running on Qemu VM
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
      # ========== Required Configs ==========
      #
      "hosts/common/core"

      #
      # ========== Optional Configs ==========
      #
      "hosts/common/optional/hyprland.nix"
      "hosts/common/optional/services/greetd.nix"
      "hosts/common/optional/services/openssh.nix"
      "hosts/common/optional/wayland.nix"
    ])
  ];

  #
  # ========== Host Specification ==========
  #

  hostSpec = {
    hostName = "griefling";
    primaryUsername = "rain";
    username = "rain";
    useWayland = true;
    useYubikey = false; # No yubikey in test VM
  };

  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  # Ensure greetd runs Hyprland session as the correct user
  services.greetd.settings.default_session.user = "rain";

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    timeout = 3;
  };
  boot.initrd = {
    systemd.enable = true;
    # This mostly mirrors what is generated on qemu from nixos-generate-config in hardware-configuration.nix
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

  # This is a fix to enable VSCode to successfully remote SSH on a client to a NixOS host
  # https://wiki.nixos.org/wiki/Visual_Studio_Code # Remote_SSH
  programs.nix-ld.enable = true;

  # Passwordless sudo for wheel group (dev VM only)
  security.sudo.wheelNeedsPassword = false;
  
  # Dev VM: Disable password requirement entirely
  users.users.rain.hashedPassword = lib.mkForce null;

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.11";
}
