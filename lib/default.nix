# Custom lib helpers for nix-config
{ lib, ... }:
rec {
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

  # ========================================
  # LEGACY MODULE BOILERPLATE HELPER
  # ========================================
  # NOTE: This is deprecated. New modules should use the automatic system below.
  #       See the autoWrapModule and autoImportModules functions.

  # Create a NixOS module with automatic boilerplate generation
  mkModule' =
    {
      path, # List of strings: [ "services" "networking" "syncthing" ]
      description, # String: "Syncthing file synchronization"
      configFn, # Function taking cfg and module args: cfg: args: { ... actual config ... }
      extraOptions ? { }, # Optional: additional options beyond just 'enable'
    }:
    args@{
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Convert kebab-case to camelCase for option names
      kebabToCamel =
        str:
        let
          parts = lib.splitString "-" str;
          capitalize = s: lib.toUpper (lib.substring 0 1 s) + lib.substring 1 (-1) s;
          first = builtins.head parts;
          rest = map capitalize (builtins.tail parts);
        in
        lib.concatStrings ([ first ] ++ rest);

      # Convert path to option path with camelCase
      optionPath = [ "myModules" ] ++ (map kebabToCamel path);

      # Get the config value at the option path
      cfg = lib.attrsets.getAttrFromPath optionPath config;
    in
    {
      options = lib.attrsets.setAttrByPath optionPath (
        {
          enable = lib.mkEnableOption description;
        }
        // extraOptions
      );

      config = lib.mkIf cfg.enable (configFn cfg args);
    };

  # ========================================
  # AUTOMATIC PATH-BASED MODULE SYSTEM
  # ========================================

  # Wrap a simple module declaration with automatic path-based options
  #
  # This function eliminates boilerplate by auto-generating:
  # - Option paths from file location (myModules.<basePath>.<category>.<name>)
  # - Full module structure with options definition
  # - cfg binding and mkIf wrapper
  #
  # Parameters:
  #   basePath: "apps" or "services"
  #   category: directory name like "networking", "audio", etc.
  #   name: file name without .nix like "syncthing", "pipewire", etc.
  #   modulePath: path to the module file
  #
  # Simple module format (modules/services/networking/syncthing.nix):
  #   { pkgs, ... }: {
  #     description = "Syncthing file synchronization";
  #     config = {
  #       services.syncthing.enable = true;
  #       environment.systemPackages = [ pkgs.syncthing ];
  #     };
  #   }
  #
  # Auto-generates:
  #   - Option: myModules.services.networking.syncthing.enable
  #   - Full NixOS module with proper structure
  #
  # Returns: Full NixOS module with auto-generated options
  autoWrapModule =
    basePath: category: name: modulePath:
    {
      config,
      lib,
      pkgs,
      ...
    }@args:
    let
      # Import the simple module and call it with args
      simpleModule = import modulePath args;

      # Convert kebab-case to camelCase for option names
      kebabToCamel =
        str:
        let
          parts = lib.splitString "-" str;
          capitalize = s: lib.toUpper (lib.substring 0 1 s) + lib.substring 1 (-1) s;
          first = builtins.head parts;
          rest = map capitalize (builtins.tail parts);
        in
        lib.concatStrings ([ first ] ++ rest);

      # Build option path: myModules.<basePath>.<category>.<name>
      optionPath = [
        "myModules"
        basePath
        (kebabToCamel category)
        (kebabToCamel name)
      ];

      # Get the config at this option path
      cfg = lib.attrsets.getAttrFromPath optionPath config;

      # Extract description and config from simple module
      description = simpleModule.description or "${name} module";
      moduleConfig = simpleModule.config or { };
      extraOptions = simpleModule.options or { };
    in
    {
      options = lib.attrsets.setAttrByPath optionPath (
        {
          enable = lib.mkEnableOption description;
        }
        // extraOptions
      );

      config = lib.mkIf cfg.enable moduleConfig;
    };

  # Scan and auto-import modules from a directory with automatic wrapping
  #
  # This function scans a category directory and automatically creates wrapped
  # imports for all .nix files (except default.nix), eliminating the need for
  # manual import lists.
  #
  # Parameters:
  #   basePath: base directory (modules/apps or modules/services)
  #   pathType: "apps" or "services" for option path generation
  #   category: subdirectory name like "networking", "browsers", etc.
  #
  # Example usage in modules/services/audio/default.nix:
  #   { lib, ... }:
  #   {
  #     imports = lib.custom.autoImportModules ./../../services "services" "audio";
  #   }
  #
  # Moving a file automatically updates its option path:
  #   modules/services/audio/tools.nix -> myModules.services.audio.tools.enable
  #   (move to) modules/services/system/tools.nix -> myModules.services.system.tools.enable
  #
  # Returns: list of wrapped module imports
  autoImportModules =
    basePath: pathType: category:
    let
      categoryPath = basePath + "/${category}";

      # Get all .nix files except default.nix
      moduleFiles = builtins.filter (f: lib.hasSuffix ".nix" f && f != "default.nix") (
        builtins.attrNames (builtins.readDir categoryPath)
      );

      # For each file, create wrapped import
      wrapFile =
        fileName:
        let
          name = lib.strings.removeSuffix ".nix" fileName;
          modulePath = categoryPath + "/${fileName}";
        in
        autoWrapModule pathType category name modulePath;
    in
    map wrapFile moduleFiles;
}
