# Misery - Headless VM for Phase 17 Testing
#
# Test host for physical security features:
# - LUKS encryption testing
# - Disaster recovery procedures
# - Golden boot safety testing
#
# IMPORTANT: This is a disposable test VM. Do not use for production.
{ ... }:
{
  imports = [ ./hardware-configuration.nix ];

  # Disk configuration with LUKS for Phase 17 testing
  disks = {
    enable = true;
    layout = "btrfs-luks-impermanence"; # Testing LUKS encryption
    device = "/dev/vda";
    withSwap = true;
    swapSize = 4; # 4GB swap for testing
  };

  # ========================================
  # ROLE SELECTION (LSP autocomplete-enabled)
  # ========================================
  # Form factor: vm (headless, minimal)
  # Task roles: test (testing features)
  roles = [
    "vm"
    "test"
  ];

  # ========================================
  # HOST IDENTITY
  # ========================================
  identity = {
    hostName = "misery";
    primaryUsername = "rain";
    hasSecrets = true; # Testing secrets with LUKS
    isProduction = false; # Test VM, not production
    persistFolder = "/persist"; # Required for impermanence layout
  };

  # ========================================
  # AUTO-UPGRADE & GOLDEN GENERATION
  # ========================================
  # Configured via task-test.nix role

  # ========================================
  # PHASE 17 TESTING NOTES
  # ========================================
  # This host is specifically for testing:
  # - LUKS encryption with password unlock
  # - Disaster recovery procedures
  # - Key rotation workflows
  # - Golden boot safety
  #
  # After validation, procedures can be applied to production hosts
}
