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

  # Remote SSH unlock configuration
  remoteUnlockEnabled = hostCfg.encryption.remoteUnlock.enable or false;
  remoteUnlockPort = hostCfg.encryption.remoteUnlock.port or 22;

  # Get authorized keys from primary user's yubikey public keys
  primaryUserKeysPath = lib.custom.relativeToRoot "modules/users/${hostCfg.primaryUsername}/keys/";
  authorizedKeys =
    if builtins.pathExists primaryUserKeysPath then
      lib.lists.forEach (lib.filesystem.listFilesRecursive primaryUserKeysPath) (
        key: builtins.readFile key
      )
    else
      [ ];

  # Clevis JWE token paths
  # Persistent storage (survives reboots, used for auto-enrollment and rebuilds)
  clevisTokenPersist = "${hostCfg.persistFolder}/etc/clevis/bcachefs-root.jwe";
  # Initrd location (where unlock service looks for it)
  clevisTokenInitrd = "/etc/clevis/bcachefs-root.jwe";
in
{
  # Define remoteUnlock options within this module (bcachefs-specific)
  options.host.encryption.remoteUnlock = lib.mkOption {
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable SSH access in initrd for remote bcachefs unlocking";
        };
        port = lib.mkOption {
          type = lib.types.int;
          default = 22;
          description = "SSH port for initrd remote unlock";
        };
      };
    };
    default = { };
    description = "Remote SSH unlock for bcachefs (only available with bcachefs encryption)";
  };

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
    boot.initrd.systemd =
      let
        # Bcachefs unlock script based on NixOS wiki pattern
        # Loops mounting until password is entered and devices are unlocked
        bcachefsUnlockScript = pkgs.writeShellScriptBin "bcachefs-unlock-root" ''
          set -e

          # Link user keyring to session keyring for key sharing
          keyctl link @u @s || true

          # Create sysroot if it doesn't exist
          mkdir -p /sysroot

          # Find all bcachefs devices
          echo "🔐 Bcachefs Unlock: Detecting encrypted devices..."
          DEVICES=$(blkid -t TYPE=bcachefs -o device 2>/dev/null || true)

          if [ -z "$DEVICES" ]; then
            echo "❌ No bcachefs devices found"
            exit 1
          fi

          echo "Found bcachefs devices:"
          echo "$DEVICES"

          # Try TPM unlock first if token exists
          ${lib.optionalString tpmEnabled ''
            TOKEN_PATH="${clevisTokenInitrd}"
            if [ -f "$TOKEN_PATH" ]; then
              echo "🔑 Attempting TPM unlock via Clevis..."
              PASSWORD=$(clevis decrypt < "$TOKEN_PATH" 2>/dev/null || true)
              if [ -n "$PASSWORD" ]; then
                for DEVICE in $DEVICES; do
                  echo "  Unlocking $DEVICE with TPM..."
                  if echo "$PASSWORD" | bcachefs unlock "$DEVICE" 2>/dev/null; then
                    echo "  ✅ $DEVICE unlocked via TPM"
                  fi
                done
              fi
            fi
          ''}

          # Mount root filesystem (will prompt for password if still locked)
          ROOT_DEVICE="/dev/disk/by-label/root"
          echo "🔐 Mounting root filesystem..."
          until bcachefs mount "$ROOT_DEVICE" /sysroot; do
            echo "⚠️  Mount failed, retrying in 1 second..."
            sleep 1
          done

          echo "✅ Root filesystem mounted successfully"

          # Mount persist filesystem if it exists
          PERSIST_DEVICE="/dev/disk/by-label/persist"
          if [ -e "$PERSIST_DEVICE" ]; then
            echo "🔐 Mounting persist filesystem..."
            mkdir -p /sysroot/persist
            until bcachefs mount "$PERSIST_DEVICE" /sysroot/persist; do
              echo "⚠️  Persist mount failed, retrying in 1 second..."
              sleep 1
            done
            echo "✅ Persist filesystem mounted successfully"
          fi

          exit 0
        '';
      in
      {
        enable = true;
        initrdBin = with pkgs; [ keyutils ];
        storePaths = [ "${bcachefsUnlockScript}/bin/bcachefs-unlock-root" ];

        # Set root shell to unlock script for interactive/remote unlock
        users.root.shell = "${bcachefsUnlockScript}/bin/bcachefs-unlock-root";

        # Include Clevis and dependencies when TPM unlock is enabled
        extraBin = lib.mkIf tpmEnabled {
          clevis = "${pkgs.clevis}/bin/clevis";
          clevis-decrypt = "${pkgs.clevis}/bin/clevis-decrypt";
          jose = "${pkgs.jose}/bin/jose";
          keyctl = "${pkgs.keyutils}/bin/keyctl";
        };
      };

    # Ensure bcachefs-tools is available in initrd
    boot.initrd.availableKernelModules =
      [
        "bcachefs"
        "sha256"
        # Note: ChaCha20/Poly1305 are built-in for kernels >= 6.15
        # For older kernels, add: "poly1305" "chacha20"
      ]
      ++ lib.optionals remoteUnlockEnabled [
        # Network drivers for remote unlock
        "r8169" # Realtek Ethernet
        "e1000e" # Intel Ethernet
        "igb" # Intel Gigabit
      ];

    # Remote SSH unlock in initrd (optional)
    boot.initrd.network = lib.mkIf remoteUnlockEnabled {
      enable = true;
      ssh = {
        enable = true;
        port = remoteUnlockPort;
        authorizedKeys = authorizedKeys;
        hostKeys = [
          # Generate persistent host key in /persist
          "${hostCfg.persistFolder}/etc/ssh/initrd_ssh_host_ed25519_key"
        ];
      };
    };

    # Configure DHCP with systemd-networkd for remote unlock
    boot.initrd.systemd.network = lib.mkIf remoteUnlockEnabled {
      enable = true;
      networks."10-ethernet" = {
        matchConfig.Name = "en*";
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = true;
        };
        dhcpV4Config.RouteMetric = 1024;
      };
    };

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
            if remoteUnlockEnabled then
              "- Remote SSH unlock in initrd (enabled on port ${toString remoteUnlockPort})"
            else
              ""
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

          ${
            if remoteUnlockEnabled then
              ''
                Remote unlock setup:
                - SSH into initrd: ssh -p ${toString remoteUnlockPort} root@<host-ip>
                - Password prompt will appear automatically
                - Authorized keys: primary user's yubikey keys
                - Host key: ${hostCfg.persistFolder}/etc/ssh/initrd_ssh_host_ed25519_key

                To enable remote unlock:
                  host.encryption.remoteUnlock.enable = true;
                  host.encryption.remoteUnlock.port = 22;  # optional, defaults to 22
              ''
            else
              ""
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
