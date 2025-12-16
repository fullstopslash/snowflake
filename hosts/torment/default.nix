# Torment - Minimal Headless Test VM for GitOps Testing
#
# Purpose: Fast-deploying headless VM for testing multi-host GitOps workflows
# - Jujutsu conflict-free merges
# - Auto-upgrade workflows
# - Concurrent dotfile edits
# - Build validation
#
# Compared to griefling: NO desktop, NO display manager, faster builds
# Paired with sorrow for multi-host testing
{ lib, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  # Disk configuration via modules/disks
  disks = {
    enable = true;
    layout = "btrfs";
    device = "/dev/vda";
    withSwap = false;
  };

  # ========================================
  # ROLE SELECTION (LSP autocomplete-enabled)
  # ========================================
  # Form factor: vm | desktop | laptop | server | pi | tablet | darwin
  # Task roles: development | mediacenter | test | fastTest
  roles = [
    "vm"
    "test"
  ];

  # ========================================
  # HOST IDENTITY
  # ========================================
  hostSpec = {
    hostName = builtins.baseNameOf (toString ./.);
    primaryUsername = "rain";
  };

  # ========================================
  # HEADLESS CONFIGURATION (override VM defaults)
  # ========================================
  # Remove desktop modules for faster builds and headless operation
  modules.services.desktop = lib.mkForce [ ];
  modules.services.display-manager = lib.mkForce [ ];

  # Keep only essential headless services for GitOps testing
  modules.services.cli = [ "atuin" ];
  modules.services.networking = [
    "openssh"
    "ssh"
    "syncthing"
    "tailscale"
  ];

  # ========================================
  # AUTO-UPGRADE (for testing GitOps workflow)
  # ========================================
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
