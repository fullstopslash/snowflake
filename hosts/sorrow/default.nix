# Sorrow - Minimal Headless Test VM for GitOps Testing
#
# Purpose: Fast-deploying headless VM for testing multi-host GitOps workflows
# - Jujutsu conflict-free merges
# - Auto-upgrade workflows
# - Concurrent dotfile edits
# - Build validation
#
# Compared to griefling: NO desktop, NO display manager, faster builds
{ lib, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  # Disk configuration via modules/disks
  # Testing Phase 20: bcachefs native encryption with impermanence
  disks = {
    enable = true;
    layout = "bcachefs-encrypt-impermanence";
    device = "/dev/vda";
    withSwap = false;
  };

  # Disable GRUB, use systemd-boot (from vmHeadless role)
  boot.loader.grub.enable = lib.mkForce false;

  # ========================================
  # ROLE SELECTION (LSP autocomplete-enabled)
  # ========================================
  # Form factor: vm-headless | vm | desktop | laptop | server | pi | tablet | darwin
  # Task roles: development | mediacenter | headless | fastTest
  roles = [
    "vmHeadless"
    "test"
  ];

  # ========================================
  # HOST IDENTITY
  # ========================================
  host = {
    hostName = builtins.baseNameOf (toString ./.);
    primaryUsername = "rain";
    persistFolder = "/persist"; # Required for bcachefs-encrypt-impermanence layout
  };

  # ========================================
  # MINIMAL SERVICES
  # ========================================
  # All essential services come from vm-headless and headless roles
  # Only add what's absolutely needed for testing

  # ========================================
  # AUTO-UPGRADE (for testing GitOps workflow)
  # ========================================
  # Test change: verifying auto-upgrade works with non-root user
  myModules.services.autoUpgrade = {
    enable = true;
    mode = "local";
    schedule = "hourly"; # Frequent for rapid testing iteration

    # Safety features from Phase 15-03b
    buildBeforeSwitch = true;

    validationChecks = [
      # Ensure critical services are enabled
      "systemctl --quiet is-enabled sshd"
      "systemctl --quiet is-enabled tailscaled"
    ];

    onValidationFailure = "rollback"; # Safest option
  };

  # ========================================
  # GOLDEN GENERATION (boot safety testing)
  # ========================================
  myModules.system.boot.goldenGeneration = {
    enable = true;
    validateServices = [
      "sshd.service"
      "tailscaled.service"
    ];
    autoPinAfterBoot = true;
  };
}
