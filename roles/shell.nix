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
    glow

    # Shell completion
    carapace
  ];
  programs = {
    foot = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
    };

    # direnv.enable = true;

    # Nushell configuration (available as package, not as program)
    # Nushell is installed as a package and configured via config files

    # Carapace completion (available as package, not as program)
    # Carapace is installed as a package and configured in nushell

    # Shell programs configuration

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
