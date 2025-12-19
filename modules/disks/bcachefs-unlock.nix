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

  # Remote SSH unlock is always enabled with bcachefs encryption
  remoteUnlockPort = 2222; # Default port for initrd SSH

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
        # Bcachefs unlock script with TPM auto-unlock support
        # Tries TPM first, falls back to password prompt
        bcachefsUnlockScript = pkgs.writeShellScriptBin "bcachefs-unlock-root" ''
          keyctl link @u @s
          mkdir -p /sysroot

          # Try TPM unlock first if token exists
          if [ -f "${clevisTokenInitrd}" ]; then
            echo "🔐 Attempting TPM auto-unlock..."
            if PASSWORD=$(clevis decrypt < "${clevisTokenInitrd}" 2>/dev/null); then
              if echo "$PASSWORD" | bcachefs mount /dev/disk/by-label/root /sysroot 2>/dev/null; then
                echo "✅ TPM unlock successful!"
                exit 0
              else
                echo "⚠️  TPM unlock failed, falling back to password prompt..."
              fi
            else
              echo "⚠️  TPM decryption failed, falling back to password prompt..."
            fi
          fi

          # Fall back to interactive password prompt
          until bcachefs mount /dev/disk/by-label/root /sysroot
          do
            sleep 1
          done
        '';
      in
      {
        enable = true;
        initrdBin = with pkgs; [ keyutils ];

        # Set root shell to unlock script for interactive/remote unlock
        users.root.shell = "${bcachefsUnlockScript}/bin/bcachefs-unlock-root";

        # extraBin for keyctl only (clevis/jose added via contents to avoid conflicts)
        extraBin = {
          keyctl = "${pkgs.keyutils}/bin/keyctl";
        };

        # Configure DHCP for remote unlock (always enabled with bcachefs encryption)
        network = {
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

        # SSH access in initrd for remote unlock
        services.sshd = {
          description = "SSH Daemon for remote unlock";
          wantedBy = [ "initrd.target" ];
          after = [ "initrd-nixos-copy-secrets.service" ];
          before = [ "initrd-switch-root.target" ];
          conflicts = [ "initrd-switch-root.target" ];
          unitConfig.DefaultDependencies = false;

          serviceConfig = {
            ExecStart = "${pkgs.openssh}/bin/sshd -D -e -f /etc/ssh/sshd_config.d/initrd.conf";
            KillMode = "process";
            Restart = "always";
          };
        };

        storePaths = [
          "${bcachefsUnlockScript}/bin/bcachefs-unlock-root"
          "${pkgs.openssh}/bin/sshd"
        ]
        ++ lib.optionals tpmEnabled [
          "${pkgs.clevis}"
          "${pkgs.jose}"
          "${pkgs.keyutils}"
          # Include token file if it exists
          (lib.mkIf (builtins.pathExists clevisTokenPersist) clevisTokenPersist)
        ];

        # Include clevis/jose packages for TPM unlock
        packages = lib.optionals tpmEnabled [
          pkgs.clevis
          pkgs.jose
        ];

        # SSH configuration files and TPM token in initrd
        contents = lib.mkMerge [
          {
            "/etc/ssh/sshd_config.d/initrd.conf".text = ''
              Port ${toString remoteUnlockPort}
              PermitRootLogin yes
              AuthorizedKeysFile /etc/ssh/authorized_keys.d/root
              HostKey /etc/ssh/initrd_ssh_host_ed25519_key
            '';
            "/etc/ssh/authorized_keys.d/root".text = lib.concatStringsSep "\n" authorizedKeys;
          }
          # Copy initrd SSH host key into initrd (must exist before encrypted /persist is unlocked)
          # NOTE: On fresh install via nixos-anywhere, this path doesn't exist during initial build
          # Initrd SSH will work after first nixos-rebuild on the installed system
          # For first boot, unlock manually or use TPM if token exists
          (lib.mkIf (builtins.pathExists "${hostCfg.persistFolder}/etc/ssh/initrd_ssh_host_ed25519_key") {
            "/etc/ssh/initrd_ssh_host_ed25519_key".source =
              "${hostCfg.persistFolder}/etc/ssh/initrd_ssh_host_ed25519_key";
          })
          # Copy TPM token to initrd using systemd.contents (not boot.initrd.secrets)
          # This avoids the evaluation-time path existence check that breaks boot.initrd.secrets
          (lib.mkIf (tpmEnabled && builtins.pathExists clevisTokenPersist) {
            "${clevisTokenInitrd}".source = clevisTokenPersist;
          })
        ];
      };

    # Ensure bcachefs-tools is available in initrd
    boot.initrd.availableKernelModules = [
      "bcachefs"
      "sha256"
      # Note: ChaCha20/Poly1305 are built-in for kernels >= 6.15
      # For older kernels, add: "poly1305" "chacha20"
      "tpm_crb" # Critical for TPM support - enables TPM hardware access in initrd
      # Network drivers for remote unlock (always enabled with bcachefs encryption)
      "r8169" # Realtek Ethernet
      "e1000e" # Intel Ethernet
      "igb" # Intel Gigabit
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
          - Remote SSH unlock in initrd (enabled on port ${toString remoteUnlockPort})

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

          Remote unlock setup:
          - SSH into initrd: ssh -p ${toString remoteUnlockPort} root@<host-ip>
          - Password prompt will appear automatically
          - Authorized keys: primary user's yubikey keys
          - Host key: ${hostCfg.persistFolder}/etc/ssh/initrd_ssh_host_ed25519_key

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

    # Copy secrets from persist into initrd
    # SSH key: Only if it exists (to avoid breaking fresh installs)
    # TPM token: Copied via boot.initrd.systemd.contents above (not boot.initrd.secrets)
    boot.initrd.secrets =
      lib.optionalAttrs
        (builtins.pathExists "${hostCfg.persistFolder}/etc/ssh/initrd_ssh_host_ed25519_key")
        {
          "/etc/ssh/initrd_ssh_host_ed25519_key" =
            "${hostCfg.persistFolder}/etc/ssh/initrd_ssh_host_ed25519_key";
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

    # NOTE: Auto-enrollment disabled - token must be generated during installation
    # See justfile: bcachefs-setup-tpm command for manual token generation
    #
    # Why disabled: Chicken-and-egg problem
    # - Token must exist BEFORE first boot for initrd to include it
    # - Service generates token AFTER first boot
    # - Solution: Generate token during installation (via justfile)
    #
    # Automatic TPM token enrollment on first boot
    # This service runs AFTER the system boots successfully (not during activation)
    # to avoid breaking nixos-anywhere installation
    systemd.services.bcachefs-tpm-auto-enroll = lib.mkIf false {
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
