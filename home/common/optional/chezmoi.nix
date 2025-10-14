{ config, pkgs, lib, ... }:
{
  # Install chezmoi (git is already installed by home/common/core/git.nix)
  home.packages = [ pkgs.chezmoi ];
  
  # Auto-initialize and apply chezmoi on activation
  home.activation.chezmoiInit = {
    after = [ "writeBoundary" ];
    before = [ ];
    data = ''
      echo "========================================"
      echo "Running chezmoi activation script..."
      echo "========================================"
      
      CHEZMOI_SOURCE="${config.home.homeDirectory}/.local/share/chezmoi"
      DOTFILES_REPO="git@github.com:fullstopslash/dotfiles.git"
      
      # Force chezmoi to use external git by setting PATH
      export PATH="${pkgs.git}/bin:$PATH"
      
      echo "Git version: $(${pkgs.git}/bin/git --version)"
      echo "Checking if $CHEZMOI_SOURCE exists..."
      
      if [ ! -d "$CHEZMOI_SOURCE/.git" ]; then
        echo "Initializing chezmoi from $DOTFILES_REPO"
        if ${pkgs.chezmoi}/bin/chezmoi init --apply "$DOTFILES_REPO"; then
          echo "✅ Chezmoi initialized successfully"
        else
          echo "⚠️  Chezmoi init failed - check SSH keys and repo access"
          echo "To init manually: chezmoi init --apply $DOTFILES_REPO"
        fi
      else
        echo "Chezmoi already initialized, updating..."
        ${pkgs.chezmoi}/bin/chezmoi update --apply || echo "⚠️  Chezmoi update failed"
      fi
      
      echo "========================================"
    '';
  };
}

