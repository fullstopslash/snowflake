# Pi role - Raspberry Pi (aarch64, headless by default)
#
# Uses unified module selection - minimal headless setup
# Secret categories: base, network
{ config, lib, ... }:
{
  config = lib.mkIf (builtins.elem "pi" config.roles) {
    # ========================================
    # MODULE SELECTIONS (minimal headless)
    # ========================================
    # Paths mirror filesystem: modules/<top>/<category> = [ "<module>" ]
    modules = {
      apps = {
        cli = [
          "comma"
          "shell"
          "tools-core"
        ];
      };
      services = {
        networking = [ "openssh" ];
      };
    };

    # ========================================
    # PI BOOTLOADER
    # ========================================
    boot.loader.grub.enable = lib.mkDefault false;
    boot.loader.generic-extlinux-compatible.enable = lib.mkDefault true;
    documentation.enable = lib.mkDefault false;

    # ========================================
    # GOLDEN GENERATION (boot safety)
    # ========================================
    # Note: Pi uses extlinux bootloader, not systemd-boot
    # Boot counting feature won't work, but validation + GC pinning still useful
    myModules.system.goldenGeneration = {
      enable = lib.mkDefault true;
      validateServices = lib.mkDefault [
        "sshd.service"
        # Note: Tailscale not in default Pi modules, hosts can add if needed
      ];
      autoPinAfterBoot = lib.mkDefault true;
    };

    # ========================================
    # CHEZMOI DOTFILE SYNC
    # ========================================
    myModules.services.dotfiles.chezmoiSync = {
      enable = lib.mkDefault false; # Disabled by default, hosts must opt-in with repoUrl
      # repoUrl must be set by host (e.g., "git@github.com:user/dotfiles.git")
      syncBeforeUpdate = lib.mkDefault true;
      autoCommit = lib.mkDefault true;
      autoPush = lib.mkDefault true;
    };

    # ========================================
    # HOSTSPEC (non-derived options only)
    # ========================================
    host = {
      # Architecture (Raspberry Pi is aarch64)
      architecture = lib.mkDefault "aarch64-linux";

      isProduction = lib.mkDefault true;
      wifi = lib.mkDefault true;

      secretCategories = {
        base = lib.mkDefault true;
        network = lib.mkDefault true;
      };
    };
  };
}
