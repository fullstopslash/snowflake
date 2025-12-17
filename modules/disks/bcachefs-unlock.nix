# Bcachefs native encryption unlock module
#
# Provides automatic boot unlock for bcachefs encrypted partitions using:
# - Primary: systemd-ask-password for interactive unlock
# - Optional: Clevis for TPM/Tang automated unlock with fallback
#
# Based on nixpkgs bcachefs.nix module design and FINDINGS from Phase 20-01.
#
# Activation:
#   Automatically enabled when disks.layout contains "bcachefs-encrypt"
#
# Boot workflow:
#   1. initrd systemd detects encrypted bcachefs device
#   2. Attempts Clevis unlock if configured (TPM/Tang)
#   3. Falls back to interactive passphrase prompt
#   4. Unlocks device via kernel keyring
#   5. Allows filesystem mount to proceed
#
# Installation bootstrap:
#   Uses /tmp/disko-password during format (Phase 17 pattern)
#   Post-install: configure Clevis or rely on interactive unlock
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.disks;

  # Check if layout uses bcachefs native encryption
  isEncrypted = lib.strings.hasInfix "bcachefs-encrypt" cfg.layout;
in
{
  config = lib.mkIf (cfg.enable && isEncrypted) {
    # Enable bcachefs filesystem support
    boot.supportedFilesystems = [ "bcachefs" ];

    # Use systemd in initrd for robust unlock workflow
    boot.initrd.systemd.enable = true;

    # Ensure bcachefs-tools is available in initrd
    boot.initrd.availableKernelModules = [
      "bcachefs"
      "sha256"
      # ChaCha20/Poly1305 modules (required for kernels < 6.15)
      "poly1305"
      "chacha20"
    ];

    # Optional Clevis configuration (users can override in host config)
    # When enabled, provides TPM/Tang automated unlock with fallback
    # Example host config:
    #   boot.initrd.clevis = {
    #     enable = true;
    #     devices."root".secretFile = "/persist/etc/clevis/root.jwe";
    #   };
    #
    # Note: NixOS bcachefs.nix module handles Clevis integration automatically
    # when boot.initrd.clevis is configured. No additional unlock logic needed here.

    # Documentation for users
    warnings = lib.optionals isEncrypted [
      ''
        Bcachefs native encryption is enabled for ${cfg.layout}.

        Boot unlock behavior:
        - Interactive passphrase prompt via systemd-ask-password (default)
        - Optional: Configure Clevis for TPM/Tang automated unlock

        To enable TPM unlock, add to your host configuration:
          boot.initrd.clevis = {
            enable = true;
            devices."root".secretFile = "/persist/etc/clevis/root.jwe";
          };

        To generate Clevis JWE token:
          1. Boot system and enter passphrase interactively
          2. Generate token: echo "passphrase" | clevis encrypt tpm2 '{"pcr_ids":"7"}' > /persist/etc/clevis/root.jwe
          3. Rebuild system to include token in initrd

        Security note:
        - ChaCha20/Poly1305 AEAD provides authenticated encryption
        - Tamper detection and replay protection included
        - Each block has unique nonce with chain of trust to superblock
        - Superior security properties compared to LUKS (unauthenticated encryption)

        Trade-offs vs LUKS:
        - No systemd-cryptenroll support (use Clevis instead)
        - Less mature tooling ecosystem
        - Use LUKS layouts if you need FIDO2/PKCS11 integration

        See docs/bcachefs.md for detailed encryption workflows.
      ''
    ];

    # Kernel keyring management
    # The bcachefs unlock process adds keys to the kernel keyring
    # NixOS bcachefs.nix module handles keyring linking automatically
    # No additional configuration needed here

    # Passphrase management notes (for documentation)
    # - Format-time: /tmp/disko-password (Phase 17 compatibility)
    # - Boot-time: systemd-ask-password (interactive) or Clevis (automated)
    # - Post-install change: bcachefs set-passphrase /dev/device
    # - Recovery: Boot from live media, unlock manually, then mount

    # Performance optimization: Use latest kernel for bcachefs improvements
    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
  };
}
