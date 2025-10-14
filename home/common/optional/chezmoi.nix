{ config, pkgs, lib, ... }:
{
  # Install chezmoi
  home.packages = [ pkgs.chezmoi ];
  
  # Auto-initialize and apply chezmoi on activation
  # Note: This will fail gracefully if the dotfiles repo doesn't exist yet
  home.activation.chezmoiInit = lib.hm.dag.entryAfter ["writeBoundary"] ''
    CHEZMOI_SOURCE="${config.home.homeDirectory}/.local/share/chezmoi"
    DOTFILES_REPO="https://github.com/fullstopslash/dotfiles.git"
    
    if [ ! -d "$CHEZMOI_SOURCE/.git" ]; then
      $DRY_RUN_CMD echo "Attempting to initialize chezmoi from dotfiles repo..."
      if $DRY_RUN_CMD ${pkgs.chezmoi}/bin/chezmoi init --apply "$DOTFILES_REPO" 2>/dev/null; then
        $DRY_RUN_CMD echo "✅ Chezmoi initialized successfully"
      else
        $DRY_RUN_CMD echo "⚠️  Dotfiles repo not found or clone failed - run 'chezmoi init $DOTFILES_REPO' manually when ready"
      fi
    else
      $DRY_RUN_CMD echo "Updating chezmoi dotfiles..."
      $DRY_RUN_CMD ${pkgs.chezmoi}/bin/chezmoi update --apply 2>/dev/null || echo "⚠️  Chezmoi update failed"
    fi
  '';
}

