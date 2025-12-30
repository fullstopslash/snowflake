# SOPS Key Enforcement Module
#
# Enforces SOPS/age key hygiene at system activation time, validating key
# permissions, format, and secret availability. Auto-enables when host.hasSecrets = true.
#
# Features:
# - Validates and fixes SSH host key and age key permissions
# - Verifies secret decryption to /run/secrets/
# - Logs warnings for permission issues (doesn't fail builds)
# - Integrates with existing SOPS setup via activation scripts and systemd services

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.security.sops-enforcement;

  # Paths to critical SOPS keys
  ageKeyPath = "/var/lib/sops-nix/key.txt";
  sshHostKeyPath = "/etc/ssh/ssh_host_ed25519_key";

  # Activation script to validate and fix key permissions
  keyValidationScript = pkgs.writeShellScript "sops-key-validation" ''
    set -euo pipefail

    echo "🔐 SOPS Key Validation Starting..."

    # Function to check and fix permissions
    check_key_perms() {
      local key_path="$1"
      local key_name="$2"

      if [ ! -f "$key_path" ]; then
        echo "⚠️  $key_name not found at $key_path (may not exist yet)"
        ${pkgs.util-linux}/bin/logger -t sops-enforcement "WARNING: $key_name not found at $key_path"
        return 0  # Don't fail, just warn
      fi

      # Get current permissions
      local current_perms=$(stat -c "%a" "$key_path")
      local current_owner=$(stat -c "%U:%G" "$key_path")

      # Check permissions (should be 600 or 400)
      if [ "$current_perms" != "600" ] && [ "$current_perms" != "400" ]; then
        echo "⚠️  $key_name has incorrect permissions: $current_perms (expected 600)"
        echo "🔧 Fixing permissions to 600..."
        chmod 600 "$key_path"
        ${pkgs.util-linux}/bin/logger -t sops-enforcement "Fixed $key_name permissions from $current_perms to 600"
        echo "✓ Fixed $key_name permissions"
      else
        echo "✓ $key_name permissions correct: $current_perms"
      fi

      # Check ownership (should be root:root or root:keys)
      if [ "$current_owner" != "root:root" ] && [ "$current_owner" != "root:keys" ]; then
        echo "⚠️  $key_name has unexpected ownership: $current_owner"
        ${pkgs.util-linux}/bin/logger -t sops-enforcement "WARNING: $key_name ownership is $current_owner (expected root:root or root:keys)"
      else
        echo "✓ $key_name ownership correct: $current_owner"
      fi
    }

    ${lib.optionalString cfg.validateKeyPermissions ''
      # Validate age key
      check_key_perms "${ageKeyPath}" "Age key"

      # Validate SSH host key
      check_key_perms "${sshHostKeyPath}" "SSH host key"
    ''}

    echo "✓ SOPS Key Validation Complete"
  '';

  # Systemd service to verify secret decryption
  verificationScript = pkgs.writeShellScript "sops-verification" ''
    set -euo pipefail

    echo "🔍 SOPS Secret Verification Starting..."

    SECRETS_DIR="/run/secrets"

    # Check if secrets directory exists
    if [ ! -d "$SECRETS_DIR" ]; then
      echo "❌ Secrets directory does not exist: $SECRETS_DIR"
      ${pkgs.util-linux}/bin/logger -t sops-enforcement "ERROR: Secrets directory not found at $SECRETS_DIR"
      exit 1
    fi

    # Count secrets (excluding parent directory references)
    SECRET_COUNT=$(find "$SECRETS_DIR" -mindepth 1 -maxdepth 1 | wc -l)

    echo "Found $SECRET_COUNT secret(s) in $SECRETS_DIR"
    ${pkgs.util-linux}/bin/logger -t sops-enforcement "Found $SECRET_COUNT secret(s) decrypted"

    ${lib.optionalString (cfg.requiredSecretCount != null) ''
      # Check if we have the required number of secrets
      REQUIRED=${toString cfg.requiredSecretCount}
      if [ "$SECRET_COUNT" -lt "$REQUIRED" ]; then
        echo "❌ Expected at least $REQUIRED secret(s), found $SECRET_COUNT"
        ${pkgs.util-linux}/bin/logger -t sops-enforcement "ERROR: Expected at least $REQUIRED secrets, found $SECRET_COUNT"
        exit 1
      fi
    ''}

    # If no specific count required, just verify we have at least one secret
    ${lib.optionalString (cfg.requiredSecretCount == null) ''
      if [ "$SECRET_COUNT" -eq 0 ]; then
        echo "❌ No secrets found but host has hasSecrets = true"
        ${pkgs.util-linux}/bin/logger -t sops-enforcement "ERROR: No secrets decrypted but host requires secrets"
        exit 1
      fi
    ''}

    echo "✓ SOPS Secret Verification Complete"
  '';
in
{
  options.myModules.security.sops-enforcement = {
    enable = lib.mkEnableOption "SOPS key enforcement and validation";

    validateKeyPermissions = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Validate and fix permissions on age and SSH keys";
    };

    validateSecretDecryption = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Verify secrets decrypted to /run/secrets successfully";
    };

    requiredSecretCount = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Minimum number of secrets expected (null = any count > 0)";
    };
  };

  config = lib.mkMerge [
    # Auto-enable when SOPS is configured
    (lib.mkIf ((config.sops.defaultSopsFile or null) != null) {
      myModules.security.sops-enforcement.enable = lib.mkDefault true;
    })

    # Implementation when enabled
    (lib.mkIf cfg.enable {
      # Activation script runs on every system activation (rebuild, boot, etc.)
      system.activationScripts.sopsKeyValidation = lib.stringAfter [ "etc" ] ''
        ${keyValidationScript}
      '';

      # Systemd service to verify secret decryption
      systemd.services.sops-verification = lib.mkIf cfg.validateSecretDecryption {
        description = "SOPS Secret Decryption Verification";
        documentation = [ "Verifies that SOPS secrets were decrypted successfully" ];

        # Run after sops-nix has decrypted secrets
        after = [ "sops-nix.service" ];
        wants = [ "sops-nix.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${verificationScript}";
          RemainAfterExit = true;
          # Don't fail the entire boot if verification fails, just log it
          # This prevents lockouts but still alerts via logs
          SuccessExitStatus = [
            0
            1
          ];
        };
      };
    })
  ];
}
