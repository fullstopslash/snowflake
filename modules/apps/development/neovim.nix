# Neovim module with mcphub.nvim integration
#
# Usage: modules.apps.development = [ "neovim" ]
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.myModules.apps.development.neovim;
in
{
  options.myModules.apps.development.neovim = {
    enable = lib.mkEnableOption "Neovim with mcphub.nvim";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      neovim
      inputs.mcp-hub.packages."${pkgs.stdenv.hostPlatform.system}".default
      nodejs_20
      jq
      luajitPackages.luarocks
      luajitPackages.magick
    ];
  };
}
