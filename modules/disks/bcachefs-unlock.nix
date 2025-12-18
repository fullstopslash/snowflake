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
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.disks;
  hostCfg = config.host;

  # SOPS folder path
  sopsFolder = builtins.toString inputs.nix-secrets + "/sops";

  # Check if layout uses bcachefs native encryption
  isEncrypted = lib.strings.hasInfix "bcachefs-encrypt" cfg.layout;

  # TPM unlock configuration
  tpmEnabled = hostCfg.encryption.tpm.enable or false;
  pcrIds = hostCfg.encryption.tpm.pcrIds or "7";

  # Clevis JWE token paths
  # Persistent storage (survives reboots, used for auto-enrollment and rebuilds)
  clevisTokenPersist = "${hostCfg.persistFolder}/etc/clevis/bcachefs-root.jwe";
  # Initrd location (where unlock service looks for it)
  clevisTokenInitrd = "/etc/clevis/bcachefs-root.jwe";
in
{
  config = lib.mkIf (cfg.enable && isEncrypted) {
    # SOPS secret for disk password (needed for auto-enrollment)
    # Uses shared.yaml default password (same as justfile bcachefs-setup-tpm)
    sops.secrets = lib.mkIf (tpmEnabled && config.host.hasSecrets) {
      "passwords/disk/default" = {
        sopsFile = "${sopsFolder}/shared.yaml";
      };
    };

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

    # TPM unlock via custom initrd systemd service
    # Note: boot.initrd.clevis is LUKS-only and doesn't work for bcachefs
    # We implement a custom service that uses Clevis for TPM unlock

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
                TPM unlock is enabled.
                Token will be automatically generated on first boot.
                After first boot, rebuild system to include token in initrd:
                  sudo nixos-rebuild switch

                Token location: ${clevisTokenPersist}
                Will be copied to initrd at: ${clevisTokenInitrd}
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

    # Include Clevis and dependencies in initrd when TPM unlock is enabled
    boot.initrd.systemd.extraBin = lib.mkIf tpmEnabled {
      clevis = "${pkgs.clevis}/bin/clevis";
      clevis-decrypt = "${pkgs.clevis}/bin/clevis-decrypt";
      jose = "${pkgs.jose}/bin/jose";
      keyctl = "${pkgs.keyutils}/bin/keyctl";
    };

    # Copy TPM token from persist into initrd
    # The token is generated on first boot and included in subsequent rebuilds
    # Only include if the token file exists (to avoid breaking fresh installs)
    boot.initrd.secrets = lib.mkIf (tpmEnabled && builtins.pathExists clevisTokenPersist) {
      "${clevisTokenInitrd}" = clevisTokenPersist;
    };

    # Make clevis available in running system for token generation
    environment.systemPackages = lib.mkIf tpmEnabled [
      pkgs.clevis
      pkgs.jose
    ];

    # Custom systemd service for TPM unlock (when enabled)
    boot.initrd.systemd.services.bcachefs-tpm-unlock = lib.mkIf tpmEnabled {
      description = "Bcachefs TPM Automatic Unlock";
      documentation = [ "Unlock bcachefs encrypted root using Clevis TPM token with password fallback" ];

      # Run early, before filesystem mounts
      unitConfig = {
        DefaultDependencies = "no";
        Before = [
          "sysroot.mount"
          "initrd-fs.target"
        ];
        After = [ "systemd-modules-load.service" ];
      };

      wantedBy = [ "initrd.target" ];

      # Service runs once and stays loaded
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set +e  # Don't exit on error - we want to try fallback

        echo "🔐 Bcachefs TPM Unlock: Starting..."

        # Find ALL encrypted bcachefs devices
        DEVICES=$(blkid -t TYPE=bcachefs -o device)

        if [ -z "$DEVICES" ]; then
          echo "❌ No bcachefs devices found"
          exit 1
        fi

        echo "Found encrypted bcachefs devices:"
        echo "$DEVICES"

        # Link kernel keyrings for proper key sharing
        keyctl link @u @s || true

        # Attempt TPM unlock via Clevis for all devices
        TOKEN_PATH="${clevisTokenInitrd}"

        if [ -f "$TOKEN_PATH" ]; then
          echo "🔑 Attempting TPM unlock via Clevis..."

          # Decrypt password once and store it
          PASSWORD=$(clevis decrypt < "$TOKEN_PATH")

          if [ $? -eq 0 ] && [ -n "$PASSWORD" ]; then
            SUCCESS=true
            for DEVICE in $DEVICES; do
              echo "  Unlocking $DEVICE..."
              if echo "$PASSWORD" | bcachefs unlock "$DEVICE"; then
                echo "  ✅ $DEVICE unlocked"
              else
                echo "  ⚠️  Failed to unlock $DEVICE"
                SUCCESS=false
              fi
            done

            if [ "$SUCCESS" = true ]; then
              echo "✅ TPM unlock successful for all devices"
              exit 0
            else
              echo "⚠️  TPM unlock failed for some devices"
              echo "Falling back to interactive password prompt..."
            fi
          else
            echo "⚠️  TPM decrypt failed"
            echo "Falling back to interactive password prompt..."
          fi
        else
          echo "ℹ️  Clevis token not found at $TOKEN_PATH"
          echo "Falling back to interactive password prompt..."
        fi

        # Fallback: Interactive password prompt via systemd-ask-password
        # Get password once and use it for all devices
        echo "🔐 Manual unlock required - enter password once for all devices"

        # Use systemd-ask-password to get the password once
        PASSWORD=$(systemd-ask-password "Enter passphrase for bcachefs devices:")

        if [ -z "$PASSWORD" ]; then
          echo "❌ No password provided"
          exit 1
        fi

        # Unlock all devices with the same password
        for DEVICE in $DEVICES; do
          echo "Unlocking $DEVICE..."
          if ! echo "$PASSWORD" | bcachefs unlock "$DEVICE"; then
            echo "❌ Manual unlock failed for $DEVICE"
            exit 1
          fi
          echo "✅ $DEVICE unlocked"
        done

        echo "✅ All devices unlocked successfully"
        exit 0
      '';
    };

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

    # Automatic TPM token enrollment on first boot
    # This service runs AFTER the system boots successfully (not during activation)
    # to avoid breaking nixos-anywhere installation
    systemd.services.bcachefs-tpm-auto-enroll = lib.mkIf tpmEnabled {
      description = "Auto-enroll TPM token for bcachefs encryption";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "sops-nix.service"
      ];
      wants = [ "network-online.target" ];

      unitConfig = {
        # Only run if token doesn't exist AND stamp file doesn't exist
        ConditionPathExists = [
          "!${clevisTokenPersist}"
          "!${hostCfg.persistFolder}/var/lib/bcachefs-tpm-enrolled.stamp"
        ];
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      path = with pkgs; [
        clevis
        jose
        bcachefs-tools
        coreutils
        gnugrep
        sops
      ];

      script = ''
        set -euo pipefail

        echo "🔐 Auto-enrolling TPM token for bcachefs..."

        # Get disk password from SOPS secret
        SOPS_FILE="${config.sops.secrets."passwords/disk/default".path}"

        if [ ! -f "$SOPS_FILE" ]; then
          echo "❌ SOPS password file not found at $SOPS_FILE"
          echo "   TPM auto-enrollment requires SOPS to be configured"
          exit 1
        fi

        DISK_PASSWORD=$(cat "$SOPS_FILE")

        if [ -z "$DISK_PASSWORD" ]; then
          echo "❌ Failed to retrieve disk password from SOPS"
          exit 1
        fi

        # Create directory for token
        mkdir -p "$(dirname "${clevisTokenPersist}")"

        # Generate Clevis JWE token with TPM2
        echo "🔑 Generating TPM2 Clevis token (PCR ${pcrIds})..."
        echo "$DISK_PASSWORD" | ${pkgs.clevis}/bin/clevis encrypt tpm2 '{"pcr_ids":"${pcrIds}"}' > "${clevisTokenPersist}"

        # Set proper permissions
        chmod 600 "${clevisTokenPersist}"
        chown root:root "${clevisTokenPersist}"

        # Create stamp file to prevent re-running
        mkdir -p "${hostCfg.persistFolder}/var/lib"
        touch "${hostCfg.persistFolder}/var/lib/bcachefs-tpm-enrolled.stamp"

        echo "✅ TPM token enrolled successfully!"
        echo "   Token location: ${clevisTokenPersist}"
        echo "   Token will be included in initrd on next rebuild"
        echo ""
        echo "⚠️  IMPORTANT: Run 'sudo nixos-rebuild switch' to include token in initrd"
        echo "   After rebuild, TPM unlock will work on next boot"
      '';
    };
  };
}
