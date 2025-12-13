# Neovim role with mcphub.nvim integration
{
  pkgs,
  inputs,
  ...
}:
{
  # Install Neovim and related tools
  environment.systemPackages = with pkgs; [
    neovim
    # Add mcphub.nvim package
    inputs.mcp-hub.packages."${pkgs.stdenv.hostPlatform.system}".default
    # Additional tools that might be needed for mcphub.nvim
    nodejs_20 # Required for mcp-hub binary
    jq # Optional, for better servers.json formatting

    # Luajit packages for neovim plugins
    luajitPackages.luarocks
    luajitPackages.magick
  ];
}
