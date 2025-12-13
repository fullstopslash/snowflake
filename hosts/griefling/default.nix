# Griefling - Desktop VM for Testing
{ ... }:
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
  # EXTRA MODULES (additive to role defaults)
  # ========================================
  # Paths mirror filesystem: extraModules.<top>.<category> = [ "<module>" ]
  extraModules.services.security = [ "bitwarden" ];
}
