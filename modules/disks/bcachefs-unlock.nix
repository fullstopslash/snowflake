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
  ...
}:
let
  cfg = config.disks;
  hostCfg = config.host;

  # Check if layout uses bcachefs native encryption
  isEncrypted = lib.strings.hasInfix "bcachefs-encrypt" cfg.layout;

  # TPM unlock configuration
  tpmEnabled = hostCfg.encryption.tpm.enable or false;
  pcrIds = hostCfg.encryption.tpm.pcrIds or "7";

  # Clevis JWE token path (stored in persist for impermanence)
  clevisTokenPath = "${hostCfg.persistFolder}/etc/clevis/bcachefs-root.jwe";
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
      # Note: ChaCha20/Poly1305 are built-in for kernels >= 6.15
      # For older kernels, add: "poly1305" "chacha20"
    ];

    # Automatic Clevis TPM configuration when enabled via host.encryption.tpm.enable
    boot.initrd.clevis = lib.mkIf tpmEnabled {
      enable = true;
      devices."root".secretFile = clevisTokenPath;
    };

    # Documentation for users
    warnings =
      lib.optionals isEncrypted [
        ''
          Bcachefs native encryption is enabled for ${cfg.layout}.

          Boot unlock behavior:
          ${
            if tpmEnabled then
              "- TPM2 automatic unlock via Clevis (enabled)"
            else
              "- Interactive passphrase prompt via systemd-ask-password"
          }

          ${
            if !tpmEnabled then
              ''
                To enable TPM unlock, add to your host configuration:
                  host.encryption.tpm.enable = true;

                After enabling, generate Clevis token:
                  sudo just bcachefs-setup-tpm
              ''
            else
              ''
                TPM unlock is enabled. Generate token with:
                  sudo just bcachefs-setup-tpm

                Token will be stored at: ${clevisTokenPath}
                Rebuild system after token generation to include in initrd.
              ''
          }

          Security note:
          - ChaCha20/Poly1305 AEAD provides authenticated encryption
          - Tamper detection and replay protection included
          - Each block has unique nonce with chain of trust to superblock
          - TPM binding to PCR ${pcrIds} (Secure Boot state)

          See docs/bcachefs.md for detailed encryption workflows.
        ''
      ]
      ++ lib.optionals (tpmEnabled && hostCfg.persistFolder == "") [
        ''
          WARNING: TPM unlock requires persistFolder to be set for token storage.
          Set host.persistFolder in your host configuration.
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

    # Note: NixOS bcachefs module already sets kernelPackages to latest
    # No need to override here
  };
}
