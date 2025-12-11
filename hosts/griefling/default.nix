# Griefling - Desktop VM for Testing
{
  inputs,
  lib,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
  ];

  # Disk configuration via modules/disks
  disks = {
    enable = true;
    layout = "btrfs";
    device = "/dev/vda";
    withSwap = false;
  };

  # ========== Identity ==========
  hostSpec = {
    hostName = builtins.baseNameOf (toString ./.); # Auto-derived from folder
    primaryUsername = "rain";
    # handle = "fullstopslash";       # Git/social handle
    # persistFolder = "/persist";    # For impermanence
  };

  # ========== Hardware (set based on actual hardware) ==========
  # hostSpec.wifi = false;
  # hostSpec.hdr = false;
  # hostSpec.scaling = "1";

  # ========== User Preferences ==========
  # hostSpec.isWork = false;
  # hostSpec.useYubikey = false;
  # hostSpec.theme = "dracula";
  # hostSpec.defaultBrowser = "firefox";
  # hostSpec.defaultEditor = "nvim";

  # ========== Hardware Roles (pick ONE) ==========
  # roles.desktop = true;
  # roles.laptop = true;
  # roles.server = true;
  # roles.pi = true;
  # roles.tablet = true;
  # roles.darwin = true;
  roles.vm = true;

  # ========== Task Roles (composable) ==========
  roles.vmHardware = true;
  roles.test = true;
  roles.secretManagement = true;
  # roles.development = true;
  # roles.mediacenter = true;
}
