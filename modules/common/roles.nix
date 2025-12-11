# Role Options Definition
#
# Defines all available roles as boolean options under config.roles.*
# Two types of roles:
#   - Hardware roles (mutually exclusive): desktop, laptop, server, pi, tablet, darwin, vm
#   - Task roles (composable): development, mediacenter
#
# Usage: roles.laptop = true; roles.development = true;
{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  options.roles = {
    # Hardware-based roles (mutually exclusive - only one can be enabled)
    desktop = lib.mkEnableOption "Desktop workstation role";
    laptop = lib.mkEnableOption "Laptop role (desktop + power management)";
    server = lib.mkEnableOption "Headless server role";
    pi = lib.mkEnableOption "Raspberry Pi role";
    tablet = lib.mkEnableOption "Tablet role (touch-friendly)";
    darwin = lib.mkEnableOption "macOS/Darwin role";
    vm = lib.mkEnableOption "Virtual machine role";

    # Task-based roles (composable - can be combined with hardware roles)
    development = lib.mkEnableOption "Development environment (IDEs, LSPs, dev tools)";
    mediacenter = lib.mkEnableOption "Media center role (media playback, streaming clients)";
  };

  # Assertions to prevent conflicting hardware roles
  config.assertions = [
    {
      assertion =
        lib.count (x: x) [
          cfg.desktop
          cfg.laptop
          cfg.server
          cfg.pi
          cfg.tablet
          cfg.darwin
          cfg.vm
        ] <= 1;
      message = "Only one hardware role can be enabled at a time (desktop, laptop, server, pi, tablet, darwin, vm)";
    }
  ];
}
