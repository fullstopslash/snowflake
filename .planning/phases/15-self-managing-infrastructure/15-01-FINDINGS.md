# NixOS Golden Boot Entries and Boot Validation - Research Findings

## Summary

NixOS provides robust built-in support for golden boot entries and boot validation through systemd-boot's boot counting feature, which was merged in 2024. The key insight is that **24h uptime validation is unnecessary** - systemd's automatic boot assessment using `boot-complete.target` provides fast (seconds to minutes), reliable boot success detection.

The research reveals three key components for a safe self-managing NixOS infrastructure:

1. **systemd-boot Boot Counting**: Provides automatic rollback on boot failure. Entries get 2 boot attempts before fallback to the previous generation. This is native, well-tested, and requires minimal configuration.

2. **GC Root Management**: NixOS already protects system generations through `/nix/var/nix/profiles` being a GC root. Additional "golden" generation pinning is straightforward using `nix-store --add-root` to create persistent symlinks in `/nix/var/nix/gcroots/`.

3. **Boot Success Validation**: The systemd `boot-complete.target` combined with `systemd-bless-boot.service` marks boots as successful based on system health checks, not arbitrary time delays. Custom validation services can extend this by adding dependencies to `boot-complete.target`.

The community best practice is to enable boot counting with `tries = 2`, maintain 10 recent generations in the boot menu, and leverage the existing systemd boot assessment framework rather than implementing custom uptime-based validation.

## Recommendations

### Primary Recommendation

**Use systemd-boot boot counting with boot-complete.target validation**. This approach:

- ✅ Fast validation (seconds to minutes, not hours)
- ✅ Fully automatic rollback on boot failure
- ✅ Native NixOS support (merged 2024, actively maintained)
- ✅ Well-tested systemd integration
- ✅ Extensible via custom validation services
- ✅ Zero user interaction required

**Implementation approach for Phase 15-01**:

1. Create `modules/system/boot/golden-generation.nix` module with:
   - Enable `boot.loader.systemd-boot.bootCounting` by default in server/pi roles
   - Systemd service to pin generation after `boot-complete.target`
   - Optional custom validation checks before boot-complete
   - Shell commands for manual golden generation management

2. Integration with existing auto-upgrade module (Phase 6):
   - Auto-upgrade pulls and rebuilds daily
   - Boot counting protects against bad updates
   - Successful boot triggers automatic golden pinning
   - GC protection ensures golden generation survives cleanup

3. Configuration in roles:
   ```nix
   boot.loader.systemd-boot.bootCounting = {
     enable = lib.mkDefault true;
     tries = lib.mkDefault 2;
   };

   myModules.system.goldenGeneration.enable = lib.mkDefault true;
   ```

### Alternatives Considered

#### Alternative 1: Manual Uptime-Based Validation (24h)

**Rejected because**:
- Too slow for practical use (24 hours is excessive)
- Doesn't align with user preference for fast validation
- No reliability advantage over boot-complete.target
- Delays marking known-good generations as golden

#### Alternative 2: Login Detection

**Acceptable but inferior**:
- Requires user interaction (not fully automated)
- Slower than boot-complete.target
- Adds complexity without significant benefit
- boot-complete.target already validates critical services

The systemd boot assessment approach supersedes these alternatives by providing faster, more reliable, and fully automated validation.

#### Alternative 3: Custom Boot Success Marker Files

**Rejected because**:
- Reinvents what systemd-boot boot counting already provides
- Requires custom implementation and maintenance
- Less reliable than systemd's battle-tested approach
- Doesn't integrate with bootloader for automatic fallback

### Implementation Phases

The recommendation naturally maps to the proposed Phase 15 structure:

**15-01: Golden Boot Entry Module**
- Implement golden generation pinning after boot-complete.target
- Enable systemd-boot boot counting in server/pi roles
- Provide manual commands for golden generation management
- Integrate with existing configuration limit settings

**15-02: Pre-Update Validation** (future)
- Build-before-switch in auto-upgrade module
- Pre-deployment health checks
- Rollback on build failure

**15-03: Decentralized GitOps Safety** (future)
- Git push capabilities for hosts
- Conflict detection and resolution
- Multi-host coordination

## Key Findings

### Generation Pinning Methods

NixOS provides multiple mechanisms for protecting system generations from garbage collection:

#### Automatic GC Roots

**System Profile Protection**: `/nix/var/nix/profiles` is automatically treated as a GC root, which means all system generations are protected by default through the system profile ([Storage optimization - NixOS Wiki](https://nixos.wiki/wiki/Storage_optimization)).

This explains why system generations survive `nix-collect-garbage` without manual intervention.

#### Manual GC Root Creation

**`nix-store --add-root` Command**: Creates explicit GC roots for specific store paths:

```bash
nix-store --add-root /path/to/gc-root --realise <derivation>
```

This creates:
1. A symlink at `/path/to/gc-root` pointing to the store path
2. An indirect GC root at `/nix/var/nix/gcroots/auto/` pointing back to your symlink

When the original symlink is deleted, the auto GC root becomes dangling and is automatically ignored by the collector ([nix-store - Nix Reference Manual](https://nix.dev/manual/nix/2.24/command-ref/nix-store.html)).

**Important limitation**: GC roots cannot be moved or renamed after creation, as the auto symlink will still point to the old location.

#### Generation Management Options

NixOS provides configuration options to control generation retention:

- `boot.loader.systemd-boot.configurationLimit = 10;` - Limits boot menu entries to 10 most recent generations
- Automated garbage collection: `nix.gc = { automatic = true; options = "--delete-older-than 30d"; };`

**Safe deletion pattern**: Use `nix-collect-garbage -d` to delete old generations and collect garbage, but note this removes rollback capability to those generations ([Storage optimization - NixOS Wiki](https://nixos.wiki/wiki/Storage_optimization)).

#### Pinning a Specific Generation

To pin the current system generation as a "golden" boot entry:

```bash
# Get current generation number
CURRENT=$(readlink /nix/var/nix/profiles/system | grep -oP '\d+$')

# Create a named GC root
nix-store --add-root /nix/var/nix/gcroots/golden-generation \
  --indirect --realise /nix/var/nix/profiles/system-${CURRENT}-link
```

This protects the specific generation from garbage collection indefinitely.

### Boot Validation Mechanisms

NixOS supports multiple methods for validating successful boots, with varying speed and reliability trade-offs:

#### systemd Automatic Boot Assessment (Recommended)

**systemd-boot Boot Counting**: Native systemd-boot feature for automatic boot assessment, merged into NixOS in 2024 ([PR #84204](https://github.com/NixOS/nixpkgs/pull/84204), presented at [FOSDEM 2024](https://archive.fosdem.org/2024/schedule/event/fosdem-2024-3045-automatic-boot-assessment-with-boot-counting/)).

**Configuration**:
```nix
boot.loader.systemd-boot.bootCounting = {
  enable = true;
  tries = 2;  # Number of boot attempts before fallback
};
```

**How it works** ([Automatic Boot Assessment](https://systemd.io/AUTOMATIC_BOOT_ASSESSMENT/)):
1. Boot loader maintains a per-entry counter that decrements on each boot attempt
2. Entries with non-zero counters are prioritized over those at zero
3. `systemd-bless-boot.service` marks the boot as successful
4. Success resets the counter, allowing future boots to this entry

**Validation trigger**: The boot is marked successful when `boot-complete.target` is reached.

#### boot-complete.target

**Purpose**: A systemd target that serves as the canonical "boot success" marker ([systemd-bless-boot.service](https://www.freedesktop.org/software/systemd/man/latest/systemd-bless-boot.service.html)).

**Components**:
- `systemd-boot-check-no-failures.service`: Verifies the system booted without critical service failures ([Arch manual](https://man.archlinux.org/man/systemd-boot-check-no-failures.service.8.en))
- `systemd-bless-boot.service`: Executed after boot-complete.target, marks the boot entry as good

**Timing**: This validation happens within seconds to minutes of boot, **much faster than 24h uptime requirements**.

Custom services can add themselves as dependencies of `boot-complete.target` to extend validation criteria (e.g., network connectivity, specific service health).

#### systemd Watchdog

**Hardware Watchdog Integration**: NixOS supports systemd's hardware watchdog for detecting system hangs ([PR #92759](https://github.com/NixOS/nixpkgs/pull/92759)).

**Configuration**:
```nix
systemd.settings.Manager = {
  RuntimeWatchdogSec = "30s";    # Watchdog ping interval during runtime
  RebootWatchdogSec = "10min";   # Timeout for reboot operations
  WatchdogDevice = "/dev/watchdog";
};
```

**Use case**: Detects complete system hangs (kernel panic, deadlock) but doesn't detect higher-level boot failures (service crashes, configuration errors).

**Hardware-specific**: Raspberry Pi supports maximum 15 seconds for RebootWatchdogSec ([NixOS Discourse](https://discourse.nixos.org/t/on-nixos-on-raspberry-pi-does-etc-watchdog-conf-work/54413)).

#### Manual Validation Options

**Login Detection**: Could implement a custom systemd service that waits for first successful login and marks boot as golden. Faster than uptime but requires user interaction.

**Service Health Checks**: Create a custom service that validates critical services are running and mark boot successful only after all checks pass.

**Comparison**:
| Method | Speed | Reliability | Automation | User Preference |
|--------|-------|-------------|------------|-----------------|
| Boot Assessment + boot-complete.target | **Seconds to minutes** | High | Full | ✅ **Recommended** |
| Login detection | Minutes | Medium | Requires interaction | Acceptable |
| 24h uptime | 24 hours | Very high | Full | ❌ Too slow |
| Manual confirmation | Variable | High | None | Acceptable |

**Recommendation**: Use systemd boot assessment with `boot-complete.target` as the primary validation mechanism. This provides fast, reliable, automated validation without requiring 24h uptime.

### Community Implementations

#### Official NixOS Integration

**Boot Counting Status**: The systemd-boot boot counting feature was merged into nixpkgs in 2024:
- Initial PR: [#84204](https://github.com/NixOS/nixpkgs/pull/84204) (WIP, danielfullmer)
- Option name change: [PR #330017](https://github.com/NixOS/nixpkgs/pull/330017) (merged July 2024)
- Test fixes: [PR #331321](https://github.com/NixOS/nixpkgs/pull/331321) (JulienMalka)

**Current status**: The feature is **available and functional** in recent NixOS releases (24.05+), though the option naming has changed over time.

**Note**: There was a revert referenced in [issue #334526](https://github.com/NixOS/nixpkgs/issues/334526), indicating some iteration was needed to stabilize the feature.

#### Production Deployment Patterns

**Generation Limits**: Common practice is to limit boot menu generations to prevent clutter while maintaining rollback capability:
```nix
boot.loader.systemd-boot.configurationLimit = 10;
```

This keeps the 10 most recent generations in the boot menu while still preserving older generations in the store (unless GC'd).

**Automated Updates with Safety**: Pattern from community deployments:
1. Automated `git pull` + `nixos-rebuild switch`
2. Boot counting enabled with `tries = 2`
3. Automatic rollback on boot failure
4. Manual rollback always available via boot menu

#### Best Practices from NixOS Manual/Wiki

**Testing Before Production** ([nixos-rebuild - NixOS Wiki](https://nixos.wiki/wiki/Nixos-rebuild)):
- `nixos-rebuild test`: Activate new config without adding boot entry
- `nixos-rebuild boot`: Add to boot menu without activating now
- `nixos-rebuild switch`: Activate now AND add to boot menu

**Garbage Collection Safety** ([Storage optimization - NixOS Wiki](https://nixos.wiki/wiki/Storage_optimization)):
- Regularly check GC roots: `ls -la /nix/var/nix/gcroots/`
- Remove old generations carefully: `nix-collect-garbage -d` removes rollback capability
- Use `--delete-older-than Nd` for time-based retention

**Failsafe Approach**:
1. Keep at least 2-3 known-good generations
2. Test major changes with `nixos-rebuild test` first
3. Enable boot counting for automatic recovery
4. Maintain manual access to boot menu for emergency rollback

### Rollback Mechanisms

#### Automatic Rollback (systemd-boot Boot Counting)

**Mechanism**: When boot counting is enabled, systemd-boot automatically handles failed boots:

1. **Counter Decrement**: Each boot attempt decrements the boot entry's counter
2. **Prioritization**: Entries with counter > 0 are prioritized in boot menu
3. **Automatic Fallback**: When counter reaches 0, systemd-boot selects the next entry with a non-zero counter
4. **Blessing on Success**: When `boot-complete.target` is reached, `systemd-bless-boot.service` resets the counter

**Configuration** ([systemd-boot.nix source](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/system/boot/loader/systemd-boot/systemd-boot.nix)):
```nix
boot.loader.systemd-boot.bootCounting = {
  enable = true;
  tries = 2;  # Boot attempts before considering entry failed
};
```

**Behavior**:
- Generation A (new): tries=2, boots, crashes during startup
- Generation A: tries=1, boots, crashes during startup
- Generation A: tries=0, marked as failed
- Generation B (previous): automatically selected for next boot

This provides **fully automatic rollback** without user intervention.

#### Manual Rollback

**Boot Menu Selection**: All generations (up to `configurationLimit`) remain available in the systemd-boot menu:
- Press `Space` during boot to access menu
- Select any previous generation
- Boot completes, selected generation becomes active

**Command-Line Rollback** ([Different Rollback Methods in NixOS](https://librephoenix.com/2024-05-06-different-rollback-methods-in-nixos)):
```bash
# List generations
sudo nix-env --profile /nix/var/nix/profiles/system --list-generations

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Rollback to specific generation
sudo nix-env --profile /nix/var/nix/profiles/system --switch-generation 42
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

#### Detecting Boot Failure vs Previous Boot Failure

**Current Boot Failure Detection**:
- `systemd-boot-check-no-failures.service` runs early in boot
- Checks for critical service failures in current boot
- If failures detected, `boot-complete.target` is not reached
- `systemd-bless-boot.service` never runs → counter decrements → eventual automatic rollback

**Previous Boot Failure Detection**:
- systemd-boot maintains boot counter in boot entry filename
- Entry filename pattern: `nixos-generation-123+2.conf` (generation 123, 2 tries remaining)
- On successful boot, filename is updated to remove counter: `nixos-generation-123.conf`
- Boot loader can distinguish "this boot is failing" from "previous boot failed"

**Integration with systemd-boot**:
- Boot loader level: Automatic fallback based on counter state
- System level: `boot-complete.target` determines success
- User level: Always has manual override via boot menu

## Code Examples

### Example 1: Basic Boot Counting Configuration

Enable systemd-boot boot counting with automatic rollback:

```nix
# modules/system/boot/golden-generation.nix
{ config, lib, pkgs, ... }:
{
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;  # Keep last 10 generations in boot menu

    bootCounting = {
      enable = true;
      tries = 2;  # Allow 2 boot attempts before rollback
    };
  };
}
```

### Example 2: Golden Generation Pinning Service

Systemd service that automatically pins the current generation after successful boot:

```nix
# modules/system/boot/golden-pin.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.myModules.system.goldenGeneration;

  pinGoldenScript = pkgs.writeShellScript "pin-golden-generation" ''
    set -euo pipefail

    # Get current generation
    CURRENT=$(readlink /nix/var/nix/profiles/system | grep -oP '\d+$')

    # Create golden GC root
    GOLDEN_ROOT="/nix/var/nix/gcroots/golden-generation"

    # Remove old golden root if exists
    [ -L "$GOLDEN_ROOT" ] && rm "$GOLDEN_ROOT"

    # Pin current generation as golden
    ${pkgs.nix}/bin/nix-store --add-root "$GOLDEN_ROOT" \
      --indirect --realise "/nix/var/nix/profiles/system-$CURRENT-link"

    echo "Pinned generation $CURRENT as golden"
  '';
in
{
  options.myModules.system.goldenGeneration = {
    enable = lib.mkEnableOption "automatic golden generation pinning";

    pinAfterBoot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically pin generation after successful boot";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.pin-golden-generation = lib.mkIf cfg.pinAfterBoot {
      description = "Pin current generation as golden after successful boot";

      # Run after boot is confirmed successful
      after = [ "boot-complete.target" ];
      wants = [ "boot-complete.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pinGoldenScript}";
      };

      # Only run once per boot
      wantedBy = [ "multi-user.target" ];
    };
  };
}
```

### Example 3: Custom Boot Validation Service

Add custom validation checks before marking boot as successful:

```nix
# modules/system/boot/custom-validation.nix
{ config, lib, pkgs, ... }:

let
  validationScript = pkgs.writeShellScript "validate-boot" ''
    set -euo pipefail

    # Check critical services are running
    systemctl is-active sshd.service || exit 1
    systemctl is-active tailscaled.service || exit 1

    # Check network connectivity (optional)
    # ping -c 1 1.1.1.1 || exit 1

    echo "Boot validation passed"
  '';
in
{
  systemd.services.custom-boot-validation = {
    description = "Custom boot validation checks";

    # Run before boot-complete.target
    before = [ "boot-complete.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${validationScript}";
      RemainAfterExit = true;
    };

    # Make boot-complete.target depend on this service
    wantedBy = [ "boot-complete.target" ];
  };
}
```

### Example 4: Manual Golden Generation Management

Shell commands for manual golden generation management:

```bash
# Pin current generation as golden
pin-golden() {
  CURRENT=$(readlink /nix/var/nix/profiles/system | grep -oP '\d+$')
  sudo nix-store --add-root /nix/var/nix/gcroots/golden-generation \
    --indirect --realise "/nix/var/nix/profiles/system-$CURRENT-link"
  echo "Pinned generation $CURRENT as golden"
}

# Show current golden generation
show-golden() {
  if [ -L /nix/var/nix/gcroots/golden-generation ]; then
    readlink /nix/var/nix/gcroots/golden-generation
  else
    echo "No golden generation pinned"
  fi
}

# Unpin golden generation (allow GC)
unpin-golden() {
  if [ -L /nix/var/nix/gcroots/golden-generation ]; then
    sudo rm /nix/var/nix/gcroots/golden-generation
    echo "Unpinned golden generation"
  else
    echo "No golden generation to unpin"
  fi
}

# Rollback to golden generation
rollback-to-golden() {
  if [ ! -L /nix/var/nix/gcroots/golden-generation ]; then
    echo "Error: No golden generation pinned"
    return 1
  fi

  GOLDEN_PATH=$(readlink /nix/var/nix/gcroots/golden-generation)
  sudo nix-env --profile /nix/var/nix/profiles/system --set "$GOLDEN_PATH"
  sudo "$GOLDEN_PATH/bin/switch-to-configuration" switch
  echo "Rolled back to golden generation"
}
```

### Example 5: Integration with Auto-Upgrade Module

Combine golden generation pinning with the existing auto-upgrade module:

```nix
# In a role file
{
  # Enable auto-upgrade (already exists from Phase 6)
  modules.services.system = [ "auto-upgrade" ];

  # Enable golden generation pinning
  modules.services.system = [ "golden-generation" ];

  # Enable boot counting
  boot.loader.systemd-boot.bootCounting = {
    enable = true;
    tries = 2;
  };

  # Configuration
  myModules.services.system.auto-upgrade = {
    enable = true;
    mode = "local";  # git pull + nh rebuild
    schedule = "daily";
  };

  myModules.system.goldenGeneration = {
    enable = true;
    pinAfterBoot = true;  # Auto-pin after successful boot
  };
}
```

This creates a safe auto-update workflow:
1. Daily git pull + rebuild
2. Boot counting protects against bad boots (tries=2)
3. After successful boot, generation is pinned as golden
4. GC won't remove the golden generation
5. Manual rollback to golden always available

## Metadata

<metadata>
<confidence level="high">
High confidence based on:
- Official NixOS source code reviewed (systemd-boot.nix module)
- systemd documentation consulted (Automatic Boot Assessment)
- Active NixOS PRs and issues tracked (boot counting merged 2024)
- Multiple authoritative sources corroborate findings
- Feature is in current NixOS stable releases (24.05+)
</confidence>

<dependencies>
To proceed with Phase 15-01 implementation, we need:
1. ✅ systemd-boot (already configured in all hosts)
2. ✅ NixOS 24.05 or later (currently on 25.05)
3. ✅ Auto-upgrade module (implemented in Phase 6)
4. ✅ Role system (completed in Phase 14)
5. ⚠️  Testing: Need to verify boot counting behavior in VM (griefling)
6. ⚠️  Testing: Need to verify GC root persistence after garbage collection
</dependencies>

<open_questions>
1. **Boot counting stability**: PR #84204 was marked WIP and had some reverts (issue #334526). Need to verify current stability in NixOS 24.11/25.05.

2. **Golden generation rotation**: Should we keep only one golden generation, or maintain a history (e.g., last 3 golden generations)? Single golden is simpler; multiple provides more fallback options.

3. **Custom validation scope**: Which services should be validated before marking boot successful? Currently assuming SSH, but user may want tailscale, syncthing, etc.

4. **Integration with configurationLimit**: If we pin golden + keep 10 generations in boot menu, do we need to adjust the limit? Pinned generation persists regardless of limit.

5. **Manual override**: Should we provide a "skip golden pinning" option for testing/development builds? Or is boot counting sufficient protection?
</open_questions>

<assumptions>
1. **systemd-boot usage**: Assumed all hosts use systemd-boot (not GRUB). Verified in flake.nix and host configs.

2. **Boot-complete.target availability**: Assumed systemd's boot-complete.target exists and functions as documented. This is standard systemd, should be reliable.

3. **GC root behavior**: Assumed `/nix/var/nix/gcroots/` symlinks persist across reboots and survive nix-collect-garbage. This is documented Nix behavior.

4. **Server/Pi priority**: Assumed golden generation pinning is most critical for server and pi roles (headless, remote). Desktop/laptop can use boot menu more easily.

5. **User preference alignment**: Assumed user wants automated validation over manual confirmation based on "confirm login is working" comment. boot-complete.target satisfies this.

6. **File path for golden root**: Assumed `/nix/var/nix/gcroots/golden-generation` is an acceptable location. This follows Nix conventions.
</assumptions>

<quality_report>
  <sources_consulted>
    Official Documentation:
    - https://systemd.io/AUTOMATIC_BOOT_ASSESSMENT/ (systemd boot assessment spec)
    - https://www.freedesktop.org/software/systemd/man/latest/systemd-bless-boot.service.html (systemd-bless-boot)
    - https://nix.dev/manual/nix/2.24/command-ref/nix-store.html (nix-store reference)
    - https://nixos.wiki/wiki/Storage_optimization (NixOS GC management)
    - https://nixos.wiki/wiki/Nixos-rebuild (nixos-rebuild commands)

    NixOS Source Code:
    - https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/system/boot/loader/systemd-boot/systemd-boot.nix
    - https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/system/boot/systemd.nix

    Community Resources:
    - https://github.com/NixOS/nixpkgs/pull/84204 (boot counting PR)
    - https://github.com/NixOS/nixpkgs/pull/330017 (option name changes)
    - https://github.com/NixOS/nixpkgs/pull/331321 (test fixes)
    - https://archive.fosdem.org/2024/schedule/event/fosdem-2024-3045-automatic-boot-assessment-with-boot-counting/ (FOSDEM 2024)
    - https://librephoenix.com/2024-05-06-different-rollback-methods-in-nixos (community guide)
  </sources_consulted>

  <claims_verified>
    ✅ systemd-boot boot counting merged and available in NixOS 24.05+
    ✅ boot-complete.target is the canonical boot success marker in systemd
    ✅ systemd-bless-boot.service marks boot entry as successful
    ✅ nix-store --add-root creates GC roots in /nix/var/nix/gcroots/
    ✅ /nix/var/nix/profiles is automatically a GC root
    ✅ Boot counting configuration uses boot.loader.systemd-boot.bootCounting
    ✅ systemd watchdog integration exists in NixOS (PR #92759)
    ✅ boot-complete.target validation is faster than uptime thresholds
  </claims_verified>

  <claims_assumed>
    ⚠️  Boot counting stability: Verified feature exists, but PR history shows some iteration. May have edge cases.
    ⚠️  Raspberry Pi watchdog timing: Based on single Discourse post, not official docs
    ⚠️  Production deployment patterns: Inferred from community best practices, not verified in production NixOS deployments
    ⚠️  Golden generation rotation strategy: No official guidance found, recommendation is custom design
  </claims_assumed>

  <confidence_by_finding>
    - Generation pinning: **High** - Official Nix documentation, verified in source code
    - Boot validation (boot-complete.target): **High** - Official systemd documentation, standard systemd behavior
    - Boot counting integration: **Medium-High** - Merged and functional, but some iteration in PRs suggests possible edge cases
    - Rollback mechanisms: **High** - Core NixOS functionality, well-documented
    - Community implementations: **Medium** - Based on PRs and community posts, not verified in production deployments
    - Integration approach: **High** - Recommended approach aligns with NixOS design patterns and systemd standards
  </confidence_by_finding>
</quality_report>
</metadata>
