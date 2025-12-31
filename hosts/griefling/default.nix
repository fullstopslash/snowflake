# Griefling - Desktop VM for Testing
{ ... }:
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
  identity = {
    hostName = builtins.baseNameOf (toString ./.);
    primaryUsername = "rain";
  };

  # ========================================
  # EXTRA MODULES (additive to role defaults)
  # ========================================
  # Paths mirror filesystem: extraModules.<top>.<category> = [ "<module>" ]
  extraModules.services.security = [ "bitwarden" ];

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
}
