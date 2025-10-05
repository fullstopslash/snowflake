# UI Zen
{ config, lib, ... }:
{
  options = {
    nixvim-config.plugins.zen-mode.enable = lib.mkEnableOption "enables zen-mode module";
  };

  config = lib.mkIf config.nixvim-config.plugins.zen-mode.enable {
    programs.nixvim.plugins = {
      zen-mode = {
        enable = true;
        settings = {
        };
      };
    };
  };
}
