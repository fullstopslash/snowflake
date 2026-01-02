# Anguish - Test VM for Bcachefs Native Encryption + TPM Unlock
#
# Purpose: Testing bcachefs native encryption with TPM automatic unlock
# - Bcachefs native encryption (not LUKS)
# - TPM2 automatic unlock via Clevis
# - Impermanence for testing
# - Headless VM (minimal, fast deploys)
#
# This VM validates the nixpkgs bcachefs.nix patterns for TPM unlock
{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    # SOPS configuration module
    (
      { inputs, ... }:
      {
        # Use shared secrets file for most secrets
        sops.defaultSopsFile = builtins.toString inputs.nix-secrets + "/sops/shared.yaml";
      }
    )
  ];

  # Disk configuration via modules/disks
  # Using bcachefs native encryption (NOT LUKS)
  # This is the key difference from sorrow which uses bcachefs-luks-impermanence
  disks = {
    enable = true;
    layout = "bcachefs-encrypt-impermanence";
    device = "/dev/vda";
    withSwap = false;
  };

  # Disable GRUB, use systemd-boot (from vmHeadless role)
  boot.loader.grub.enable = lib.mkForce false;

  # Enable mDNS resolution for .lan domains (resolves waterbug.lan automatically)
  services.avahi = {
    enable = true;
    nssmdns4 = true; # Enable .local and .lan domain resolution via mDNS
  };

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
  identity = {
    hostName = builtins.baseNameOf (toString ./.);
    primaryUsername = "rain";
    persistFolder = "/persist"; # Required for impermanence layout
    hasSecrets = true; # Enable SOPS secret decryption

    # Encryption configuration
    encryption = {
      # TPM automatic unlock via Clevis (bcachefs native encryption)
      # Server VM: auto-unlock on boot (no manual password needed)
      # Token generated during installation or via: just bcachefs-setup-tpm anguish
      tpm = {
        enable = true;
        pcrIds = "0+7"; # Boot components + Secure Boot state
      };
    };
  };

  # ========================================
  # AUTO-UPGRADE & GOLDEN GENERATION
  # ========================================
  # Configured via task-test.nix role
  # - Hourly auto-upgrade for rapid testing iteration
  # - Build validation and rollback on failure
  # - Golden generation auto-pinning after successful boot
}
