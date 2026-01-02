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
  imports = [
    ./hardware-configuration.nix
    # SOPS configuration module
    (
      { inputs, ... }:
      {
        # Use shared secrets file for most secrets
        sops.defaultSopsFile = builtins.toString inputs.nix-secrets + "/sops/shared.yaml";
      }
    )
  ];

  # Disk configuration via modules/disks
  disks = {
    enable = true;
    layout = "btrfs";
    device = "/dev/vda";
    withSwap = false;
  };

  # Disable GRUB, use systemd-boot (from vmHeadless role)
  boot.loader.grub.enable = lib.mkForce false;

  # Enable mDNS resolution for .lan domains (resolves waterbug.lan automatically)
  services.avahi = {
    enable = true;
    nssmdns4 = true; # Enable .local and .lan domain resolution via mDNS
  };

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
  identity = {
    hostName = builtins.baseNameOf (toString ./.);
    primaryUsername = "rain";
  };

  # ========================================
  # BUILD CACHE (Attic binary cache)
  # ========================================
  # Enable binary cache for faster builds
  myModules.services.buildCache.enable = true;
  # enableBuilder and enablePush default to false (not the build machine)

  # ========================================
  # AUTO-UPGRADE & GOLDEN GENERATION
  # ========================================
  # Configured via task-test.nix role
  # - Hourly auto-upgrade for rapid testing iteration
  # - Build validation and rollback on failure
  # - Golden generation auto-pinning after successful boot
}
