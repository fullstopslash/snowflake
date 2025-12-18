# Sorrow - Minimal Headless Test VM for GitOps Testing
#
# Purpose: Fast-deploying headless VM for testing multi-host GitOps workflows
# - Jujutsu conflict-free merges
# - Auto-upgrade workflows
# - Concurrent dotfile edits
# - Build validation
#
# Compared to griefling: NO desktop, NO display manager, faster builds
{ lib, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  # Disk configuration via modules/disks
  # Testing Phase 20: bcachefs native encryption with impermanence
  disks = {
    enable = true;
    layout = "bcachefs-encrypt-impermanence";
    device = "/dev/vda";
    withSwap = false;
  };

  # Disable GRUB, use systemd-boot (from vmHeadless role)
  boot.loader.grub.enable = lib.mkForce false;

  # Force disable GUI packages for minimal VM
  programs.kdeconnect.enable = lib.mkForce false;
  services.displayManager.sddm.enable = lib.mkForce false;
  services.hardware.openrgb.enable = lib.mkForce false;
  services.printing.enable = lib.mkForce false;

  # ========================================
  # ROLE SELECTION (LSP autocomplete-enabled)
  # ========================================
  # Form factor: vm-headless | vm | desktop | laptop | server | pi | tablet | darwin
  # Task roles: development | mediacenter | headless | fastTest
  roles = [
    "vmHeadless"
    "test"
  ];

  # ========================================
  # HOST IDENTITY
  # ========================================
  host = {
    hostName = builtins.baseNameOf (toString ./.);
    primaryUsername = "rain";
    persistFolder = "/persist"; # Required for bcachefs-encrypt-impermanence layout

    # TPM automatic unlock for bcachefs encryption
    # Server VM: auto-unlock on boot (no manual password needed)
    encryption.tpm.enable = true;
  };

  # ========================================
  # AUTO-UPGRADE & GOLDEN GENERATION
  # ========================================
  # Configured via task-test.nix role
  # - Hourly auto-upgrade for rapid testing iteration
  # - Build validation and rollback on failure
  # - Golden generation auto-pinning after successful boot
}
