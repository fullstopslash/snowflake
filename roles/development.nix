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
    zeal
    dasht # for general API docs
    tealdeer # for command examples
    manix # for Nix documentation

    # Android development
    android-tools

    # Terminal and shell
    zellij

    # Language runtimes
    python3
    pylint
    jdk
    go
    cmake

    # Editors
    zed-editor
    vscodium-fhs
    helix
    fresh-editor
    neovide
    micro

    #Git management
    gittyup
    # gitbutler
    meld
    kdePackages.kompare

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
    inputs.mcphub-nvim.packages."${pkgs.stdenv.hostPlatform.system}".default
    inputs.mcp-hub.packages."${pkgs.stdenv.hostPlatform.system}".default # mcp-hub binary
    nodejs_20 # Required for mcp-hub binary
    jq # Optional, for better servers.json formatting
  ];

  # Neovim configuration with mcphub.nvim integration
  programs.neovim = {
    enable = true;
  };
}
