# Host Template - Copy this for new hosts
#
# The unified module selection system:
# - roles = [...] selects your hardware form factor and optional task roles
# - Roles set default module selections via lib.mkDefault
# - extraModules.* adds host-specific modules to role defaults (additive)
# - modules.* can be overridden with lib.mkForce if needed (replaces)
#
# Available roles (LSP autocomplete-enabled):
#   Form factors (pick ONE):  desktop, laptop, vm, server, pi, tablet, darwin
#   Task roles (composable):  development, mediacenter, test, fastTest
#
# Available module categories (for extraModules.*):
#   desktop, displayManager, apps, cli, development, services, audio, ai, security
#
# To see available modules for each category, check modules/selection.nix
# or use your LSP - values are typed enums for autocompletion.
#
{ ... }:
{
  imports = [ ./hardware-configuration.nix ];

  # ========================================
  # ROLE SELECTION (LSP autocomplete-enabled)
  # ========================================
  # Form factor: vm | desktop | laptop | server | pi | tablet | darwin
  # Task roles: development | mediacenter | test | fastTest
  roles = [ "desktop" ]; # Full graphical workstation
  # roles = [ "laptop" ];               # Portable with power management
  # roles = [ "vm" "test" ];            # VM with test settings
  # roles = [ "server" ];               # Headless production server
  # roles = [ "desktop" "development" ]; # Desktop + dev tools

  # ========================================
  # EXTRA MODULES (additive to role defaults)
  # ========================================
  # Add host-specific modules without replacing role defaults
  # extraModules.apps = [ "productivity" ];
  # extraModules.services = [ "tailscale" "syncthing" ];
  # extraModules.development = [ "rust" ];

  # ========================================
  # MODULE OVERRIDES (replaces role defaults)
  # ========================================
  # Use lib.mkForce to completely replace a category
  # modules.desktop = lib.mkForce [ "niri" "wayland" ];

  # ========================================
  # HOST IDENTITY (required)
  # ========================================
  hostSpec.hostName = "your-hostname";

  # ========================================
  # HARDWARE SPECIFICS (optional)
  # ========================================
  # hostSpec.wifi = true;      # Has wifi capability
  # hostSpec.hdr = true;       # HDR display support
  # hostSpec.scaling = "1.5";  # Display scaling factor

  # ========================================
  # DISK CONFIGURATION (optional)
  # ========================================
  # disks = {
  #   enable = true;
  #   layout = "btrfs";  # or "btrfs-impermanence", "btrfs-luks-impermanence"
  #   device = "/dev/vda";
  #   withSwap = false;
  # };

  system.stateVersion = "25.05";
}
