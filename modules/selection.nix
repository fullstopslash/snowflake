# Filesystem-Driven Module Selection System
#
# This module auto-generates selection options from the /modules filesystem.
# Selection paths DIRECTLY mirror the filesystem structure:
#
#   modules.services.desktop = [ "hyprland" "wayland" ];
#   -> enables modules/services/desktop/hyprland.nix and wayland.nix
#
#   modules.apps.cli = [ "shell" "tools" ];
#   -> enables modules/apps/cli/shell.nix and tools.nix
#
# Adding a new module = just create the .nix file. No manual list updates needed.
#
# Structure:
#   modules.apps.<category> = [ "<module-names>" ];    # -> modules/apps/<category>/<name>.nix
#   modules.services.<category> = [ "<module-names>" ]; # -> modules/services/<category>/<name>.nix
#
# Usage in roles (sets defaults):
#   modules.services.desktop = [ "hyprland" "wayland" ];
#
# Usage in hosts (additive):
#   extraModules.services.security = [ "bitwarden" ];  # Adds to role's defaults
#
{ config, lib, ... }:
let
  cfg = config.modules;
  extraCfg = config.extraModules;

  # ========================================
  # FILESYSTEM SCANNING
  # ========================================

  modulesPath = ./.;
  appsPath = modulesPath + "/apps";
  servicesPath = modulesPath + "/services";

  # Inline versions of lib.custom.scanDirNames and scanModuleNames
  # (avoiding dependency on lib.custom which may not be available during option evaluation)
  scanDirNames =
    path:
    builtins.filter (f: (builtins.readDir path).${f} == "directory") (
      builtins.attrNames (builtins.readDir path)
    );

  scanModuleNames =
    path:
    builtins.map (f: lib.strings.removeSuffix ".nix" f) (
      builtins.filter (f: lib.hasSuffix ".nix" f && f != "default.nix") (
        builtins.attrNames (builtins.readDir path)
      )
    );

  # Get list of category directories
  appsCategories = scanDirNames appsPath;
  servicesCategories = scanDirNames servicesPath;

  # Get modules for a category (excludes default.nix, strips .nix suffix)
  getModulesForCategory = basePath: category: scanModuleNames (basePath + "/${category}");

  # ========================================
  # OPTION GENERATION
  # ========================================

  # Create an option for a category with enum from filesystem
  mkCategoryOption =
    basePath: category:
    let
      modules = getModulesForCategory basePath category;
    in
    lib.mkOption {
      type = lib.types.listOf (lib.types.enum modules);
      default = [ ];
      description = "Modules from ${category}/ to enable. Available: ${toString modules}";
    };

  # Generate all category options for a base path (apps or services)
  mkCategoryOptions = basePath: categories: lib.genAttrs categories (mkCategoryOption basePath);

  # ========================================
  # SELECTION HELPERS
  # ========================================

  # Check if a module is selected (from modules or extraModules)
  # For nested: isSelected "services" "desktop" "hyprland"
  isSelectedNested =
    topLevel: category: name:
    builtins.elem name (cfg.${topLevel}.${category} or [ ])
    || builtins.elem name (extraCfg.${topLevel}.${category} or [ ]);

  # ========================================
  # TRANSLATION LAYER GENERATION
  # ========================================

  # Convert kebab-case to camelCase for option names
  # e.g., "document-processing" -> "documentProcessing"
  kebabToCamel =
    str:
    let
      parts = lib.splitString "-" str;
      capitalize = s: lib.toUpper (lib.substring 0 1 s) + lib.substring 1 (-1) s;
      first = builtins.head parts;
      rest = map capitalize (builtins.tail parts);
    in
    lib.concatStrings ([ first ] ++ rest);

  # Generate translation for a single module
  # topLevel = "apps" or "services", category = "desktop", name = "hyprland"
  mkModuleTranslation =
    topLevel: category: name:
    let
      # Convert both category and module name to camelCase for option path
      # e.g., "display-manager" -> "displayManager", "ai-tools" -> "aiTools"
      categoryOption = kebabToCamel category;
      optionName = kebabToCamel name;
      # The option path: myModules.<topLevel>.<categoryOption>.<optionName>.enable
      optionPath = [
        "myModules"
        topLevel
        categoryOption
        optionName
        "enable"
      ];
    in
    lib.setAttrByPath optionPath (lib.mkIf (isSelectedNested topLevel category name) true);

  # Generate translations for all modules in a category
  mkCategoryTranslations =
    topLevel: basePath: category:
    let
      modules = getModulesForCategory basePath category;
    in
    map (mkModuleTranslation topLevel category) modules;

  # Generate all translations for a top-level (apps or services)
  mkTopLevelTranslations =
    topLevel: basePath: categories:
    lib.flatten (map (mkCategoryTranslations topLevel basePath) categories);

  # Merge all translations into a single attrset
  allTranslations =
    let
      appsTranslations = mkTopLevelTranslations "apps" appsPath appsCategories;
      servicesTranslations = mkTopLevelTranslations "services" servicesPath servicesCategories;
    in
    lib.mkMerge (appsTranslations ++ servicesTranslations);

in
{
  # ========================================
  # MODULE OPTIONS
  # ========================================

  options.modules = {
    apps = mkCategoryOptions appsPath appsCategories;
    services = mkCategoryOptions servicesPath servicesCategories;
  };

  # ========================================
  # EXTRA MODULES OPTIONS (additive)
  # ========================================

  options.extraModules = {
    apps = mkCategoryOptions appsPath appsCategories;
    services = mkCategoryOptions servicesPath servicesCategories;
  };

  # ========================================
  # TRANSLATION LAYER
  # ========================================

  config = allTranslations;
}
