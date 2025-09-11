# Shell configuration role
{pkgs, ...}: {
  # Shell packages
  environment.systemPackages = with pkgs; [
    # Shells
    zsh
    fish
    nushell

    # Shell tools
    fzf
    atuin
    zoxide
    starship
    direnv
    glow

    # Terminal
    ghostty
    kitty
    alacritty
    foot
    rio

    # Terminal Toys
    neo
    tmatrix

    # Shell completion
    carapace
  ];

  # Nushell configuration (available as package, not as program)
  # Nushell is installed as a package and configured via config files

  # Carapace completion (available as package, not as program)
  # Carapace is installed as a package and configured in nushell

  # Shell programs configuration
  programs = {
    starship = {
      enable = true;
      settings = {
        add_newline = true;
        character = {
          success_symbol = "[➜](bold green)";
          error_symbol = "[➜](bold red)";
        };
      };
    };
    zsh = {
      enable = true;
      enableGlobalCompInit = false;
    };
    tmux = {
      enable = true;
    };
    zoxide = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
    };
  };
}
