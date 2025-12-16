# Host Template - Copy this for new hosts
#
# The unified module selection system:
# - roles = [...] selects your hardware form factor and optional task roles
# - Roles set default module selections
# - extraModules.* adds host-specific modules to role defaults (additive)
# - modules.* can be overridden with lib.mkForce if needed (replaces)
#
# Available roles (LSP autocomplete-enabled):
#   Form factors (pick ONE):  desktop, laptop, vm, server, pi, tablet, darwin
#   Task roles (composable):  development, mediacenter, test, fastTest
#
# Module selection paths mirror filesystem structure:
#   modules.apps.<category> = [ "<module>" ]     -> modules/apps/<category>/<module>.nix
#   modules.services.<category> = [ "<module>" ] -> modules/services/<category>/<module>.nix
#
# To see available modules for each category, browse the modules/ directory
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
  # Paths mirror filesystem: extraModules.<top>.<category> = [ "<module>" ]
  #
  # extraModules.apps.productivity = [ "default" ];
  # extraModules.services.networking = [ "tailscale" "syncthing" ];
  # extraModules.apps.development = [ "rust" ];

  # ========================================
  # MODULE OVERRIDES (replaces role defaults)
  # ========================================
  # Use lib.mkForce to completely replace a category
  # modules.services.desktop = lib.mkForce [ "niri" "wayland" ];

  # ========================================
  # HOST IDENTITY (required)
  # ========================================
  host.hostName = "your-hostname";

  # ========================================
  # HARDWARE SPECIFICS (optional)
  # ========================================
  # host.wifi = true;      # Has wifi capability
  # host.hdr = true;       # HDR display support
  # host.scaling = "1.5";  # Display scaling factor

  # ========================================
  # DISK CONFIGURATION (optional)
  # ========================================
  # disks = {
  #   enable = true;
  #   layout = "btrfs";  # or "btrfs-impermanence", "btrfs-luks-impermanence"
  #   device = "/dev/vda";
  #   withSwap = false;
  # };

  # Note: system.stateVersion is set centrally in flake.nix
}
