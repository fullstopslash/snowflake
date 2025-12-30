# Neovim module with mcphub.nvim integration
#
# Usage: modules.apps.development = [ "neovim" ]
{ pkgs, inputs, ... }:
{
  # Neovim with mcphub.nvim
  config = {
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
