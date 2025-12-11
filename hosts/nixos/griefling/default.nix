# Griefling - Test VM for Core Services
# NixOS on QEMU VM with desktop environment
{
  inputs,
  lib,
  config,
  ...
}:
{
  imports = [
    # Home Manager (unstable - can't use hosts/common/core)
    inputs.home-manager-unstable.nixosModules.home-manager

    # Hardware & Disk
    ./hardware-configuration.nix
    inputs.disko.nixosModules.disko
    (lib.custom.relativeToRoot "hosts/common/disks/btrfs-disk.nix")
    {
      _module.args = {
        disk = "/dev/vda";
        withSwap = false;
      };
    }

    # Core modules (manual since unstable HM)
    (lib.custom.relativeToRoot "modules/common")
    (lib.custom.relativeToRoot "hosts/common/core/nixos.nix")
    (lib.custom.relativeToRoot "hosts/common/core/sops")
    (lib.custom.relativeToRoot "hosts/common/core/ssh.nix")
    (lib.custom.relativeToRoot "hosts/common/users")

    # nix-index for comma
    inputs.nix-index-database.nixosModules.nix-index
  ];

  # Roles: desktop + VM hardware + test settings
  roles.desktop = true;
  roles.vmHardware = true;
  roles.test = true;

  # Identity
  hostSpec.hostName = "griefling";

  # Feature toggles
  roles.bitwardenAutomation = {
    enable = true;
    enableAutoLogin = true;
    syncInterval = 30;
  };
  myModules.services.nixConfigRepo.enable = true;
  programs.nix-index-database.comma.enable = true;

  # Home Manager (unstable requires explicit config)
  home-manager = {
    useGlobalPkgs = true;
    backupFileExtension = "bk";
    extraSpecialArgs = {
      inherit inputs;
      hostSpec = config.hostSpec;
    };
  };

  # LY display manager TTY
  services.displayManager.ly.settings.tty = lib.mkForce 2;
  services.displayManager.sddm.enable = lib.mkForce false;

  system.stateVersion = "23.11";
}
