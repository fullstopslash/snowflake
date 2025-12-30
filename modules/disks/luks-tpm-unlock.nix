# LUKS TPM2 automatic unlock module
#
# Provides automatic TPM enrollment for LUKS-encrypted devices.
# Gracefully handles systems without TPM by skipping enrollment.
#
# Activation:
#   Automatically enabled when using LUKS-based disk layouts
#   and host.encryption.tpm.enable = true
#
# Boot workflow:
#   1. systemd-cryptsetup attempts TPM unlock (if enrolled)
#   2. Falls back to password prompt if TPM unavailable/fails
#
# First boot workflow:
#   1. System boots with password-only unlock
#   2. Auto-enrollment service runs after successful boot
#   3. Checks for TPM device availability
#   4. Enrolls TPM if available and not already enrolled
#   5. Next boot uses TPM automatic unlock
#
# TPM detection:
#   - Checks /dev/tpmrm0 (TPM resource manager)
#   - Checks systemd-cryptenroll --tpm2-device=list
#   - Gracefully skips if no TPM detected
#
# Portability:
#   - Works on physical hardware with TPM 2.0
#   - Works on VMs with emulated TPM (QEMU swtpm)
#   - Gracefully degrades to password-only on systems without TPM
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.disks;

  # SOPS folder path
  sopsFolder = builtins.toString inputs.nix-secrets + "/sops";

  # Check if layout uses LUKS encryption
  isLuks = lib.strings.hasInfix "luks" cfg.layout;

  # TPM unlock configuration
  tpmEnabled = config.hardware.host.encryption.tpm.enable or false;
  pcrIds = config.hardware.host.encryption.tpm.pcrIds or "0+7";
  persistFolder = config.hardware.host.persistFolder or "";

  # LUKS device path (standardized name across all LUKS layouts)
  luksDevice = "/dev/disk/by-id/dm-name-encrypted-nixos";
  luksDeviceAlt = "/dev/mapper/encrypted-nixos"; # Fallback path
in
{
  config = lib.mkIf (cfg.enable && isLuks && tpmEnabled) {
    # SOPS secret for disk password (needed for auto-enrollment)
    sops.secrets = lib.mkIf ((config.sops.defaultSopsFile or null) != null) {
      "passwords/disk/default" = {
        sopsFile = "${sopsFolder}/shared.yaml";
      };
    };

    # Ensure systemd-cryptenroll is available
    environment.systemPackages = [ pkgs.systemd ];

    # Automatic TPM enrollment on first boot
    # Runs after successful boot, checks for TPM, enrolls if available
    systemd.services.luks-tpm-auto-enroll = {
      description = "Auto-enroll TPM2 token for LUKS encryption";
      wantedBy = [ "multi-user.target" ];
      after = [
        "systemd-cryptsetup@encrypted\\x2dnixos.service"
        "sops-nix.service"
      ];
      wants = [ ];

      unitConfig = {
        # Only run if stamp file doesn't exist (prevents re-running)
        ConditionPathExists = "!${persistFolder}/var/lib/luks-tpm-enrolled.stamp";
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      path = with pkgs; [
        systemd
        coreutils
        gnugrep
        util-linux
      ];

      script = ''
        set -euo pipefail

        echo "🔐 LUKS TPM Auto-Enrollment"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        # Detect LUKS device
        LUKS_DEV=""
        if [ -e "${luksDevice}" ]; then
          LUKS_DEV="${luksDevice}"
        elif [ -e "${luksDeviceAlt}" ]; then
          LUKS_DEV="${luksDeviceAlt}"
        else
          echo "❌ LUKS device not found"
          echo "   Expected: ${luksDevice} or ${luksDeviceAlt}"
          exit 1
        fi

        echo "📦 LUKS device: $LUKS_DEV"

        # Check if TPM is available
        if [ ! -e /dev/tpmrm0 ]; then
          echo "⚠️  No TPM device detected (/dev/tpmrm0 not found)"
          echo "   System will continue using password-only unlock"
          echo "   This is normal for systems without TPM hardware"

          # Create stamp file to prevent repeated checks
          mkdir -p "${persistFolder}/var/lib"
          touch "${persistFolder}/var/lib/luks-tpm-enrolled.stamp"
          exit 0
        fi

        echo "✅ TPM device detected: /dev/tpmrm0"

        # Check if TPM slot already enrolled
        if cryptsetup luksDump "$LUKS_DEV" | grep -q "systemd-tpm2"; then
          echo "✅ TPM already enrolled"

          # Create stamp file
          mkdir -p "${persistFolder}/var/lib"
          touch "${persistFolder}/var/lib/luks-tpm-enrolled.stamp"
          exit 0
        fi

        echo "🔑 TPM not yet enrolled, starting enrollment..."

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

        # Create temporary password file
        TEMP_PASS=$(mktemp)
        echo -n "$DISK_PASSWORD" > "$TEMP_PASS"
        chmod 600 "$TEMP_PASS"

        # Enroll TPM with password file
        echo "🔐 Enrolling TPM2 token (PCRs: ${pcrIds})..."

        if systemd-cryptenroll \
          --tpm2-device=auto \
          --tpm2-pcrs=${pcrIds} \
          --unlock-key-file="$TEMP_PASS" \
          "$LUKS_DEV"; then

          echo "✅ TPM enrollment successful!"
          echo ""
          echo "📊 LUKS key slots:"
          cryptsetup luksDump "$LUKS_DEV" | grep -A 2 "Key Slot"
          echo ""
          echo "🔄 TPM automatic unlock will be active on next boot"

          # Create stamp file
          mkdir -p "${persistFolder}/var/lib"
          touch "${persistFolder}/var/lib/luks-tpm-enrolled.stamp"
        else
          echo "❌ TPM enrollment failed"
          echo "   System will continue using password-only unlock"
          rm -f "$TEMP_PASS"
          exit 1
        fi

        # Clean up
        rm -f "$TEMP_PASS"
      '';
    };
  };
}
