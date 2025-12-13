# Host Template - Copy this for new hosts
#
# The unified module selection system:
# - Roles set default selections via lib.mkDefault
# - Hosts inherit from roles and can override specific categories
# - modules.* lists determine what software is installed
# - hostSpec behavioral options (useWayland, isDevelopment, etc.) are derived from selections
#
# Available selection categories:
#   modules.desktop       - Window managers, desktop environments
#   modules.displayManager- Display managers (ly, greetd)
#   modules.apps          - Application categories (media, gaming, comms, productivity)
#   modules.cli           - CLI tools and shell config (shell, tools, zellij)
#   modules.development   - Dev tools (latex, containers, document-processing)
#   modules.services      - System services (atuin, syncthing, tailscale)
#   modules.audio         - Audio stack (pipewire, easyeffects)
#   modules.ai            - AI tools (ollama, crush)
#   modules.security      - Security tools (secrets, yubikey)
#
# To see available modules for each category, check modules/selection.nix
# or use your LSP - values are typed enums for autocompletion.
#
{ lib, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  # ========================================
  # ROLE SELECTION
  # ========================================
  # Pick ONE hardware role (sets sensible defaults)
  roles.desktop = true;  # Full graphical workstation
  # roles.laptop = true;   # Portable with power management
  # roles.vm = true;       # Virtual machine
  # roles.server = true;   # Headless production server
  # roles.pi = true;       # Raspberry Pi
  # roles.tablet = true;   # Touch-friendly device

  # Optional: Add task roles for additional capabilities (composable)
  # roles.development = true;  # Development tools
  # roles.mediacenter = true;  # Media consumption

  # ========================================
  # MODULE OVERRIDES (optional)
  # ========================================
  # Override or extend role's module selections
  # modules.desktop = lib.mkForce [ "niri" "wayland" ];  # Replace defaults
  # modules.services = [ "tailscale" ];                   # Extend defaults

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
