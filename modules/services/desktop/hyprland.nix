# Hyprland desktop module
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.myModules.desktop.hyprland;
in
{
  options.myModules.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland desktop";
  };

  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
    };

    environment.systemPackages = [
      inputs.rose-pine-hyprcursor.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
