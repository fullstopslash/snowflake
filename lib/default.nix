# Custom lib helpers for nix-config
{ lib, ... }:
{
  # ========================================
  # MODULE SELECTION HELPERS
  # ========================================

  # Scan a directory and return module names (without .nix extension, excluding default.nix)
  # Used for generating enum values for the selection system
  # Example: scanModuleNames ./modules/apps/media -> [ "media" "obs" ]
  # Example: scanModuleNames ./modules/services/desktop -> [ "common" "hyprland" "niri" "plasma" "waybar" "wayland" ]
  scanModuleNames =
    path:
    builtins.map (f: lib.strings.removeSuffix ".nix" f) (
      builtins.filter (f: lib.hasSuffix ".nix" f && f != "default.nix") (
        builtins.attrNames (builtins.readDir path)
      )
    );

  # Scan a directory and return subdirectory names (for categories like modules/apps/*)
  # Example: scanDirNames ./modules/apps -> [ "ai" "browsers" "cli" ... ]
  scanDirNames =
    path:
    builtins.filter (f: (builtins.readDir path).${f} == "directory") (
      builtins.attrNames (builtins.readDir path)
    );

  # ========================================
  # PATH HELPERS
  # ========================================

  # Use path relative to the root of the project
  relativeToRoot = lib.path.append ../.;

  # Scan a directory for all .nix files and subdirectories (excluding default.nix)
  # Useful for auto-importing modules
  scanPaths =
    path:
    builtins.map (f: (path + "/${f}")) (
      builtins.attrNames (
        lib.attrsets.filterAttrs (
          path: _type:
          (_type == "directory") # include directories
          || (
            (path != "default.nix") # ignore default.nix
            && (lib.strings.hasSuffix ".nix" path) # include .nix files
          )
        ) (builtins.readDir path)
      )
    );

  # Import all .nix files from a directory (excluding default.nix)
  # Useful for importing role modules
  importDir =
    path:
    map (f: import (path + "/${f}")) (
      builtins.filter (f: lib.hasSuffix ".nix" f && f != "default.nix") (
        builtins.attrNames (builtins.readDir path)
      )
    );

  # Check if a path exists
  pathExists = path: builtins.pathExists path;
}
