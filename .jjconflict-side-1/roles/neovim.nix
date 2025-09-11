# Neovim role with mcphub.nvim integration
{
  pkgs,
  inputs,
  ...
}: {
  # Neovim configuration with mcphub.nvim integration
  programs.neovim = {
    enable = true;

    # Configure mcphub.nvim
    extraConfig = ''
      -- MCP Hub configuration
      require("mcphub").setup()
    '';
  };

  # Install Neovim and related tools
  environment.systemPackages = with pkgs; [
    neovim
    # Add mcphub.nvim package
    inputs.mcphub-nvim.packages."${pkgs.system}".default
    # Additional tools that might be needed for mcphub.nvim
    nodejs_20 # Required for mcp-hub binary
    jq # Optional, for better servers.json formatting
  ];
}
