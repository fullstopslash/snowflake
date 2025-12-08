# Host specification module for declarative host differentiation
{
  config,
  lib,
  ...
}: {
  options.hostSpec = {
    hostname = lib.mkOption {
      type = lib.types.str;
      description = "The hostname of the host (set automatically by flake)";
    };

    system = lib.mkOption {
      type = lib.types.str;
      description = "System architecture (x86_64-linux, aarch64-linux, aarch64-darwin)";
      example = "x86_64-linux";
    };

    stateVersion = lib.mkOption {
      type = lib.types.str;
      description = "NixOS state version (set automatically by flake)";
      example = "25.05";
    };

    isDesktop = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Desktop workstation with GUI";
    };

    isServer = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Headless server";
    };

    isLaptop = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Portable machine with battery";
    };

    isDarwin = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "macOS host";
    };

    isMinimal = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Minimal installation (ISO, containers)";
    };

    hasWifi = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Has wireless networking capability";
    };

    primaryUser = lib.mkOption {
      type = lib.types.str;
      description = "Primary username for the host";
      example = "rain";
    };
  };
}
