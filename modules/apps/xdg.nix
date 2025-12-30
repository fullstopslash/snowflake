# XDG Default Applications Module
#
# Defines default applications for various file types and actions.
# These are user preferences, not host identity.
#
# Options:
# - myModules.apps.xdg.defaultBrowser: Default web browser
# - myModules.apps.xdg.defaultEditor: Default text editor
# - myModules.apps.xdg.defaultDesktop: Default desktop session
#
{ config, lib, ... }:
let
  cfg = config.myModules.apps.xdg;
  inherit (lib)
    mkEnableOption
    mkOption
    types
    mkIf
    ;
in
{
  options.myModules.apps.xdg = {
    enable = mkEnableOption "XDG default applications configuration";

    defaultBrowser = mkOption {
      type = types.str;
      default = "firefox";
      description = "Default web browser";
      example = "chromium";
    };

    defaultEditor = mkOption {
      type = types.str;
      default = "nvim";
      description = "Default text editor command";
      example = "code";
    };

    defaultDesktop = mkOption {
      type = types.str;
      default = "Hyprland";
      description = "Default desktop session";
      example = "plasma";
    };
  };

  config = mkIf cfg.enable {
    # This module primarily provides option definitions
    # The actual XDG configuration is applied in home-manager/xdg.nix
  };
}
