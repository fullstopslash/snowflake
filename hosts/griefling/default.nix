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
  extraModules.apps.cli = [ "tools-full" ];
  extraModules.services.security = [ "bitwarden" ];

  # Enable mDNS resolution for .lan domains (resolves waterbug.lan automatically)
  services.avahi = {
    enable = true;
    nssmdns4 = true; # Enable .local and .lan domain resolution via mDNS
  };

  # ========================================
  # BUILD CACHE (Attic binary cache)
  # ========================================
  # Enable binary cache for faster builds
  myModules.services.buildCache = {
    enable = true;
    enablePush = true; # All hosts push to cache
  };
  # enableBuilder defaults to false (only malphas is the build machine)

  # ========================================
  # AUTO-UPGRADE & GOLDEN GENERATION
  # ========================================
  # Configured via task-test.nix role
}
