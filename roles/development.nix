# Development role
{
  pkgs,
  inputs,
  ...
}: {
  # Development packages
  environment.systemPackages = with pkgs; [
    # Core development tools
    vim
    tree

    # Android development
    android-tools

    # Terminal and shell
    zellij

    # Language runtimes
    python3
    jdk
    go
    cmake

    # Editors
    zed-editor
    vscodium-fhs
    helix
    neovide
    micro
    gittyup

    # Development AI tools
    code-cursor-fhs
    claude-code
    gemini-cli

    discord
    discordo

    # System utilities

    # Network tools (in networking role)
    imagemagick
    luajitPackages.luarocks
    luajitPackages.magick

    # Git tools (skip to avoid duplication)

    # Removed duplicates (centralized)

    # Neovim enabled via programs.neovim below
    mermaid-cli

    # mcphub.nvim and dependencies
    inputs.mcphub-nvim.packages."${pkgs.system}".default
    inputs.mcp-hub.packages."${pkgs.system}".default # mcp-hub binary
    nodejs_20 # Required for mcp-hub binary
    jq # Optional, for better servers.json formatting
  ];

  # Neovim configuration with mcphub.nvim integration
  programs.neovim = {
    enable = true;
  };
}
