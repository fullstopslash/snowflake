# Automatic Rollback Design - Phase 15-01

## Problem Statement

The `boot.loader.systemd-boot.bootCounting` option doesn't exist in NixOS 25.05 or current unstable. We need to implement automatic rollback on boot failure without relying on this feature.

## Requirements

1. Detect boot failures (boot didn't reach successful validation)
2. Count consecutive boot failures
3. After N failures (N=2), automatically rollback to golden generation and reboot
4. Reset counter on successful boot
5. Work with any bootloader (systemd-boot, GRUB, extlinux)
6. Survive across reboots (persistent state)

## Design: Boot Validation State Machine

### State Files

Located in `/var/lib/golden-generation/`:
- `boot-pending` - Created at boot start, removed on success (indicates "boot needs validation")
- `boot-failures` - Counter file, contains number of consecutive failures
- `last-boot-status` - "success" or "failed" for logging/debugging

### State Flow

```
Boot Start
    ↓
[1. Check Previous Boot Status]
    ↓
    Is boot-pending file present?
    ├─ NO → Previous boot succeeded
    │        - Continue normally
    │        - Create new boot-pending file
    │
    └─ YES → Previous boot FAILED
             - Increment boot-failures counter
             - Check counter >= 2?
                 ├─ NO → Continue (try again)
                 │        - Log failure
                 │        - Create new boot-pending file
                 │
                 └─ YES → ROLLBACK
                          - Set system profile to golden generation
                          - Execute switch-to-configuration boot
                          - Reboot immediately
                          - (Note: This rollback boot will have counter=0 since it's a different generation)

    ↓
[2. Boot Continues]
    ↓
[3. Validation Services Run]
    ↓
[4. boot-complete.target Reached]
    ↓
[5. Mark Boot Successful]
    - Remove boot-pending file
    - Reset boot-failures to 0
    - Pin current generation as golden
```

### Service Order

1. **golden-boot-init.service** (earliest, before validation)
   - Order: `before = [ "multi-user.target" "golden-boot-validation.service" ]`
   - Runs: Check for boot-pending, handle failures, create new boot-pending
   - Critical: Must run before anything that could fail

2. **golden-boot-validation.service** (existing, runs before boot-complete)
   - Order: `before = [ "boot-complete.target" ]`
   - Runs: Validate required services (SSH, Tailscale, etc.)
   - If fails: boot-complete.target never reached → boot-pending never removed

3. **golden-boot-success.service** (after boot-complete)
   - Order: `after = [ "boot-complete.target" ]`
   - Runs: Remove boot-pending, reset counter, pin golden
   - Only runs if validation succeeded

## Implementation Details

### Service 1: Boot Initialization (golden-boot-init.service)

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="/var/lib/golden-generation"
PENDING_FILE="$STATE_DIR/boot-pending"
FAILURES_FILE="$STATE_DIR/boot-failures"
MAX_FAILURES=2

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
    logger -t golden-generation "Boot failure detected (attempt $FAILURES)"

    # Check if we should rollback
    if [ "$FAILURES" -ge "$MAX_FAILURES" ]; then
        echo "❌ Maximum boot failures reached ($FAILURES >= $MAX_FAILURES)"
        echo "🔄 Rolling back to golden generation..."
        logger -t golden-generation "Maximum boot failures, rolling back to golden"

        # Check if golden generation exists
        if [ ! -L /nix/var/nix/gcroots/golden-generation ]; then
            echo "⚠️  No golden generation pinned, cannot rollback"
            logger -t golden-generation "ERROR: No golden generation to rollback to"
            # Reset counter and hope for the best
            echo "0" > "$FAILURES_FILE"
        else
            # Rollback to golden
            GOLDEN_PATH=$(readlink /nix/var/nix/gcroots/golden-generation)
            nix-env --profile /nix/var/nix/profiles/system --set "$GOLDEN_PATH"

            # Reset counter (golden generation should boot successfully)
            echo "0" > "$FAILURES_FILE"

            # Switch to golden configuration and reboot
            "$GOLDEN_PATH/bin/switch-to-configuration" boot

            echo "✓ Rolled back to golden generation, rebooting..."
            logger -t golden-generation "Rolled back to golden, rebooting"

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
```

### Service 2: Boot Success (golden-boot-success.service)

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="/var/lib/golden-generation"
PENDING_FILE="$STATE_DIR/boot-pending"
FAILURES_FILE="$STATE_DIR/boot-failures"

# Remove pending file (boot succeeded)
rm -f "$PENDING_FILE"

# Reset failure counter
echo "0" > "$FAILURES_FILE"

echo "✓ Boot validation successful"
logger -t golden-generation "Boot validation successful, counter reset"

# Pin current generation as golden (if autoPinAfterBoot is enabled)
# This is handled by existing pin-golden-generation.service
```

### Systemd Service Definitions

**golden-boot-init.service**:
```nix
systemd.services.golden-boot-init = {
  description = "Golden Generation Boot Initialization";
  documentation = [ "Check for previous boot failures and handle rollback" ];

  # Run VERY early, before almost everything
  before = [ "multi-user.target" "golden-boot-validation.service" ];
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
```

**golden-boot-success.service** (replaces pin-golden-generation.service):
```nix
systemd.services.golden-boot-success = {
  description = "Mark Boot as Successful and Pin Golden";
  documentation = [ "Clears boot-pending flag and resets failure counter" ];

  # Run after boot validation succeeds
  after = [ "boot-complete.target" ];
  wants = [ "boot-complete.target" ];

  serviceConfig = {
    Type = "oneshot";
    ExecStart = "${bootSuccessScript}";
  };

  wantedBy = [ "multi-user.target" ];
};
```

## Testing Scenarios

### Test 1: Normal Boot (No Failures)
1. Boot system
2. golden-boot-init: No pending file → create new pending
3. Validation services run successfully
4. boot-complete.target reached
5. golden-boot-success: Remove pending, reset counter, pin golden
6. Result: ✓ Boot successful, generation pinned

### Test 2: Single Boot Failure
1. Boot system
2. Break SSH service (simulates failure)
3. Validation fails → boot-complete.target not reached
4. Pending file NOT removed
5. Reboot
6. golden-boot-init: Pending file exists → increment counter (now 1)
7. Counter < 2 → continue boot
8. Fix SSH, boot succeeds
9. Result: ✓ Recovery after single failure

### Test 3: Double Boot Failure (Triggers Rollback)
1. Boot system (generation N)
2. Break SSH service
3. Validation fails, pending file remains
4. Reboot
5. golden-boot-init: Counter = 1, continue
6. Still broken, validation fails again
7. Reboot
8. golden-boot-init: Counter = 2 → ROLLBACK
9. Switch to golden generation (generation N-1)
10. Reboot into golden
11. Result: ✓ Automatic rollback to last known-good

### Test 4: No Golden Generation (Edge Case)
1. Boot fails 2 times
2. golden-boot-init: No golden generation pinned
3. Log error, reset counter, continue
4. Result: ⚠️ Can't rollback but doesn't get stuck

## Advantages Over systemd-boot bootCounting

✅ **Available Now**: Works with current NixOS versions
✅ **Bootloader Agnostic**: Works with systemd-boot, GRUB, extlinux
✅ **Transparent**: State files are visible and debuggable
✅ **Persistent**: State survives across reboots
✅ **Manual Override**: Admin can reset counter or remove pending file
✅ **Logging**: All actions logged via logger for debugging

## Migration Path to systemd-boot bootCounting

When `boot.loader.systemd-boot.bootCounting` becomes available:

1. Keep custom rollback logic as **fallback** for non-systemd-boot systems
2. Add conditional config:
   ```nix
   boot.loader.systemd-boot.bootCounting = lib.mkIf (systemd-boot is enabled) {
     enable = lib.mkDefault true;
     tries = lib.mkDefault 2;
   };
   ```
3. Custom logic detects systemd-boot boot counting and defers to it
4. Or: Replace custom logic entirely with boot counting once stable

## File Structure Changes

```
modules/system/boot/golden-generation.nix
├── Options (unchanged)
├── Scripts
│   ├── validationScript (unchanged)
│   ├── bootInitScript (NEW - check failures, rollback if needed)
│   ├── bootSuccessScript (NEW - clear pending, reset counter, pin golden)
│   └── Manual commands (unchanged)
└── Services
    ├── golden-boot-init (NEW)
    ├── golden-boot-validation (unchanged)
    └── golden-boot-success (NEW - replaces pin-golden-generation)
```

## Security Considerations

1. **State directory permissions**: `/var/lib/golden-generation/` should be root-owned
2. **Atomic operations**: Use `mv` instead of `echo >` for state changes
3. **Reboot protection**: Only reboot if rollback successful
4. **Logging**: All rollback actions logged for audit trail

## Open Questions

1. **Counter threshold**: Is 2 failures the right number? (Answer: Yes, matches systemd-boot default)
2. **State persistence**: Should state survive nix-collect-garbage? (Answer: Yes, in /var)
3. **Manual reset**: Should we provide `reset-boot-failures` command? (Answer: Yes, useful for debugging)
4. **Grace period**: Should we wait X seconds before rollback? (Answer: No, immediate is safer)

## Next Steps

1. Implement bootInitScript and bootSuccessScript
2. Add golden-boot-init and golden-boot-success services
3. Test in griefling VM with simulated failures
4. Document manual intervention procedures
5. Add `reset-boot-failures` command for manual recovery
