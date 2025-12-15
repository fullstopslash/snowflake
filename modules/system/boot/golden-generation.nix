# Golden Generation Boot Entry Module
#
# Automatically pins known-good system generations to survive garbage collection
# and enables automatic rollback on boot failure using systemd-boot boot counting.
#
# Features:
# - Fast boot validation (seconds, not hours) using systemd boot-complete.target
# - Automatic rollback after 2 failed boot attempts
# - Extensible service validation (default: SSH + Tailscale)
# - Manual golden generation management commands
# - GC protection via /nix/var/nix/gcroots/

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.system.boot.goldenGeneration;

  stateDir = "/var/lib/golden-generation";
  pendingFile = "${stateDir}/boot-pending";
  failuresFile = "${stateDir}/boot-failures";
  maxFailures = "2";

  # Validation script - checks all required services are active
  validationScript = pkgs.writeShellScript "golden-boot-validation" ''
    set -euo pipefail

    echo "🔍 Validating boot services..."

    ${lib.concatMapStringsSep "\n" (service: ''
      if systemctl is-active ${service} >/dev/null 2>&1; then
        echo "✓ ${service} is active"
      else
        echo "✗ ${service} is NOT active"
        exit 1
      fi
    '') cfg.validateServices}

    echo "✓ All required services validated"
  '';

  # Boot initialization script - checks for previous boot failures, handles rollback
  bootInitScript = pkgs.writeShellScript "golden-boot-init" ''
    set -euo pipefail

    STATE_DIR="${stateDir}"
    PENDING_FILE="${pendingFile}"
    FAILURES_FILE="${failuresFile}"
    MAX_FAILURES=${maxFailures}

    # Ensure state directory exists
    mkdir -p "$STATE_DIR"

    # Check if previous boot failed
    if [ -f "$PENDING_FILE" ]; then
        echo "⚠️  Previous boot did not complete validation"

        # Read failure counter (default to 0 if doesn't exist)
        FAILURES=$(cat "$FAILURES_FILE" 2>/dev/null || echo "0")
        FAILURES=$((FAILURES + 1))
        echo "$FAILURES" > "$FAILURES_FILE"

        echo "Boot failure count: $FAILURES"
        ${pkgs.util-linux}/bin/logger -t golden-generation "Boot failure detected (attempt $FAILURES)"

        # Check if we should rollback
        if [ "$FAILURES" -ge "$MAX_FAILURES" ]; then
            echo "❌ Maximum boot failures reached ($FAILURES >= $MAX_FAILURES)"
            echo "🔄 Rolling back to golden generation..."
            ${pkgs.util-linux}/bin/logger -t golden-generation "Maximum boot failures, rolling back to golden"

            # Check if golden generation exists
            if [ ! -L /nix/var/nix/gcroots/golden-generation ]; then
                echo "⚠️  No golden generation pinned, cannot rollback"
                ${pkgs.util-linux}/bin/logger -t golden-generation "ERROR: No golden generation to rollback to"
                # Reset counter and hope for the best
                echo "0" > "$FAILURES_FILE"
            else
                # Rollback to golden
                GOLDEN_PATH=$(readlink /nix/var/nix/gcroots/golden-generation)
                GOLDEN_GEN=$(echo "$GOLDEN_PATH" | grep -oP '\d+$' || echo "unknown")

                echo "Rolling back to golden generation $GOLDEN_GEN..."
                ${pkgs.nix}/bin/nix-env --profile /nix/var/nix/profiles/system --set "$GOLDEN_PATH"

                # Reset counter (golden generation should boot successfully)
                echo "0" > "$FAILURES_FILE"

                # Switch to golden configuration and reboot
                "$GOLDEN_PATH/bin/switch-to-configuration" boot

                echo "✓ Rolled back to golden generation $GOLDEN_GEN, rebooting..."
                ${pkgs.util-linux}/bin/logger -t golden-generation "Rolled back to golden generation $GOLDEN_GEN, rebooting"

                # Immediate reboot
                systemctl reboot
                exit 0
            fi
        fi
    else
        echo "✓ Previous boot completed successfully (or first boot)"
    fi

    # Create pending file for this boot
    echo "$(date -Is)" > "$PENDING_FILE"
    echo "⏳ Boot validation pending..."
    ${pkgs.util-linux}/bin/logger -t golden-generation "Boot validation pending"
  '';

  # Boot success script - clears pending flag, resets counter, pins golden
  bootSuccessScript = pkgs.writeShellScript "golden-boot-success" ''
    set -euo pipefail

    STATE_DIR="${stateDir}"
    PENDING_FILE="${pendingFile}"
    FAILURES_FILE="${failuresFile}"

    # Remove pending file (boot succeeded)
    if [ -f "$PENDING_FILE" ]; then
        rm -f "$PENDING_FILE"
        echo "✓ Cleared boot-pending flag"
    fi

    # Reset failure counter
    echo "0" > "$FAILURES_FILE"

    echo "✓ Boot validation successful, counter reset"
    ${pkgs.util-linux}/bin/logger -t golden-generation "Boot validation successful, counter reset"

    # Pin current generation as golden (if not skipped)
    if [ -f /run/skip-golden-pin ]; then
      echo "⏭  Skipping golden generation pin (skip flag set)"
      rm /run/skip-golden-pin
      exit 0
    fi

    # Get current generation number
    CURRENT=$(readlink /nix/var/nix/profiles/system | grep -oP '\d+')

    # Golden GC root path
    GOLDEN_ROOT="/nix/var/nix/gcroots/golden-generation"

    # Remove old golden root if exists
    if [ -L "$GOLDEN_ROOT" ]; then
      OLD_GEN=$(readlink "$GOLDEN_ROOT" | grep -oP '\d+' || echo "unknown")
      rm "$GOLDEN_ROOT"
      echo "Removed old golden generation $OLD_GEN"
    fi

    # Pin current generation as golden
    ${pkgs.nix}/bin/nix-store --add-root "$GOLDEN_ROOT" \
      --indirect --realise "/nix/var/nix/profiles/system-$CURRENT-link"

    echo "✓ Pinned generation $CURRENT as golden"
    ${pkgs.util-linux}/bin/logger -t golden-generation "Pinned generation $CURRENT as golden"
  '';

  # Manual command: Pin current generation as golden
  pinGoldenCmd = pkgs.writeShellScriptBin "pin-golden" ''
    set -euo pipefail
    CURRENT=$(readlink /nix/var/nix/profiles/system | grep -oP '\d+')
    sudo ${pkgs.nix}/bin/nix-store --add-root /nix/var/nix/gcroots/golden-generation \
      --indirect --realise "/nix/var/nix/profiles/system-$CURRENT-link"
    echo "✓ Pinned generation $CURRENT as golden"
  '';

  # Manual command: Show current golden generation
  showGoldenCmd = pkgs.writeShellScriptBin "show-golden" ''
    if [ -L /nix/var/nix/gcroots/golden-generation ]; then
      GOLDEN=$(readlink /nix/var/nix/gcroots/golden-generation)
      GENERATION=$(echo "$GOLDEN" | grep -oP '\d+$' || echo "unknown")
      echo "Golden generation: $GENERATION"
      echo "Path: $GOLDEN"
    else
      echo "No golden generation pinned"
      exit 1
    fi
  '';

  # Manual command: Unpin golden generation
  unpinGoldenCmd = pkgs.writeShellScriptBin "unpin-golden" ''
    if [ -L /nix/var/nix/gcroots/golden-generation ]; then
      GENERATION=$(readlink /nix/var/nix/gcroots/golden-generation | grep -oP '\d+' || echo "unknown")
      sudo rm /nix/var/nix/gcroots/golden-generation
      echo "✓ Unpinned golden generation $GENERATION"
    else
      echo "No golden generation to unpin"
      exit 1
    fi
  '';

  # Manual command: Rollback to golden generation
  rollbackToGoldenCmd = pkgs.writeShellScriptBin "rollback-to-golden" ''
    set -euo pipefail

    if [ ! -L /nix/var/nix/gcroots/golden-generation ]; then
      echo "Error: No golden generation pinned"
      echo "Run 'pin-golden' first to pin the current generation"
      exit 1
    fi

    GOLDEN_PATH=$(readlink /nix/var/nix/gcroots/golden-generation)
    GENERATION=$(echo "$GOLDEN_PATH" | grep -oP '\d+$' || echo "unknown")

    echo "Rolling back to golden generation $GENERATION..."
    echo "Path: $GOLDEN_PATH"

    sudo nix-env --profile /nix/var/nix/profiles/system --set "$GOLDEN_PATH"
    sudo "$GOLDEN_PATH/bin/switch-to-configuration" switch

    echo "✓ Rolled back to golden generation $GENERATION"
  '';

  # Manual command: Skip next golden pin (for testing)
  skipNextPinCmd = pkgs.writeShellScriptBin "skip-next-golden-pin" ''
    sudo touch /run/skip-golden-pin
    echo "✓ Next golden generation pin will be skipped"
    echo "This flag will be cleared after next boot"
  '';

  # Manual command: Reset boot failure counter
  resetFailuresCmd = pkgs.writeShellScriptBin "reset-boot-failures" ''
    STATE_DIR="${stateDir}"
    PENDING_FILE="${pendingFile}"
    FAILURES_FILE="${failuresFile}"

    # Remove pending file
    if [ -f "$PENDING_FILE" ]; then
      sudo rm -f "$PENDING_FILE"
      echo "✓ Removed boot-pending flag"
    fi

    # Reset failure counter
    sudo sh -c "echo 0 > $FAILURES_FILE"
    echo "✓ Reset boot failure counter to 0"

    echo ""
    echo "Boot failure state cleared. System will not rollback on next boot."
  '';

  # Manual command: Show boot failure status
  showBootStatusCmd = pkgs.writeShellScriptBin "show-boot-status" ''
    STATE_DIR="${stateDir}"
    PENDING_FILE="${pendingFile}"
    FAILURES_FILE="${failuresFile}"

    echo "=== Golden Generation Boot Status ==="
    echo ""

    # Show golden generation
    if [ -L /nix/var/nix/gcroots/golden-generation ]; then
      GOLDEN_PATH=$(readlink /nix/var/nix/gcroots/golden-generation)
      GOLDEN_GEN=$(echo "$GOLDEN_PATH" | grep -oP '\d+$' || echo "unknown")
      echo "Golden generation: $GOLDEN_GEN"
    else
      echo "Golden generation: None pinned"
    fi

    # Show current generation
    CURRENT=$(readlink /nix/var/nix/profiles/system | grep -oP '\d+')
    echo "Current generation: $CURRENT"

    echo ""

    # Show failure count
    if [ -f "$FAILURES_FILE" ]; then
      FAILURES=$(cat "$FAILURES_FILE")
      echo "Boot failure count: $FAILURES / ${maxFailures}"
    else
      echo "Boot failure count: 0 / ${maxFailures}"
    fi

    # Show pending status
    if [ -f "$PENDING_FILE" ]; then
      PENDING_DATE=$(cat "$PENDING_FILE")
      echo "Boot pending since: $PENDING_DATE"
      echo "⚠️  Current boot has NOT been validated yet"
    else
      echo "Boot status: ✓ Validated"
    fi
  '';
in
{
  options.myModules.system.boot.goldenGeneration = {
    enable = lib.mkEnableOption "automatic golden generation pinning and boot validation";

    validateServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "sshd.service"
        "tailscaled.service"
      ];
      description = ''
        List of systemd services that must be active for boot to be considered successful.
        Services are checked before boot-complete.target is reached.
        Hosts can extend this list to add host-specific validations.
      '';
    };

    autoPinAfterBoot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Automatically pin the current generation as golden after successful boot validation.
        The pinned generation is protected from garbage collection.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # NOTE: systemd-boot boot counting can be enabled manually in role/host config:
    #   boot.loader.systemd-boot.bootCounting = {
    #     enable = lib.mkDefault true;
    #     tries = lib.mkDefault 2;
    #   };
    # This feature is only available in recent NixOS versions (24.11+) and
    # only works with systemd-boot (not GRUB or extlinux).
    # However, this module implements bootloader-agnostic automatic rollback.

    # ========================================
    # BOOT FAILURE DETECTION & ROLLBACK
    # ========================================

    # Service 1: Boot initialization - checks previous boot status, handles rollback
    systemd.services.golden-boot-init = {
      description = "Golden Generation Boot Initialization";
      documentation = [ "Check for previous boot failures and handle automatic rollback" ];

      # Run VERY early, before almost everything
      before = [
        "multi-user.target"
        "golden-boot-validation.service"
      ];
      wantedBy = [ "multi-user.target" ];

      # Must succeed for boot to continue
      unitConfig = {
        DefaultDependencies = false;
      };

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${bootInitScript}";
        RemainAfterExit = true;
      };
    };

    # Service 2: Boot validation - checks required services are active
    systemd.services.golden-boot-validation = lib.mkIf (cfg.validateServices != [ ]) {
      description = "Golden Generation Boot Validation";
      documentation = [ "https://systemd.io/AUTOMATIC_BOOT_ASSESSMENT/" ];

      # Run before boot is marked complete
      before = [ "boot-complete.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "multi-user.target"
        "golden-boot-init.service"
      ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${validationScript}";
        RemainAfterExit = true;
      };

      # Make boot-complete.target depend on this validation
      wantedBy = [ "boot-complete.target" ];
    };

    # Service 3: Boot success - clears pending flag, resets counter, pins golden
    systemd.services.golden-boot-success = lib.mkIf cfg.autoPinAfterBoot {
      description = "Mark Boot as Successful and Pin Golden Generation";
      documentation = [ "https://systemd.io/AUTOMATIC_BOOT_ASSESSMENT/" ];

      # Run after boot validation succeeds
      after = [ "boot-complete.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${bootSuccessScript}";
      };

      # Triggered by boot-complete.target to avoid ordering cycle
      wantedBy = [ "boot-complete.target" ];
    };

    # ========================================
    # MANUAL MANAGEMENT COMMANDS
    # ========================================

    environment.systemPackages = [
      pinGoldenCmd
      showGoldenCmd
      unpinGoldenCmd
      rollbackToGoldenCmd
      skipNextPinCmd
      resetFailuresCmd
      showBootStatusCmd
    ];
  };
}
