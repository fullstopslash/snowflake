{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  options.roles = {
    desktop = lib.mkEnableOption "Desktop workstation role";
    laptop = lib.mkEnableOption "Laptop role (desktop + power management)";
    server = lib.mkEnableOption "Headless server role";
    pi = lib.mkEnableOption "Raspberry Pi role";
    tablet = lib.mkEnableOption "Tablet role (touch-friendly)";
    darwin = lib.mkEnableOption "macOS/Darwin role";
    vm = lib.mkEnableOption "Virtual machine role";
  };

  # Assertions to prevent conflicting roles
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
      message = "Only one device role can be enabled at a time";
    }
  ];
}
