{ config, pkgs, lib, ... }:
{
  # Install chezmoi
  home.packages = [ pkgs.chezmoi ];
  
  # Auto-initialize and apply chezmoi on activation
  home.activation.chezmoiInit = lib.hm.dag.entryAfter ["writeBoundary"] ''
    CHEZMOI_SOURCE="${config.home.homeDirectory}/.local/share/chezmoi"
    
    if [ ! -d "$CHEZMOI_SOURCE/.git" ]; then
      $DRY_RUN_CMD echo "Initializing chezmoi from dotfiles repo..."
      $DRY_RUN_CMD ${pkgs.chezmoi}/bin/chezmoi init --apply https://github.com/fullstopslash/dotfiles.git
    else
      $DRY_RUN_CMD echo "Updating chezmoi dotfiles..."
      $DRY_RUN_CMD ${pkgs.chezmoi}/bin/chezmoi update --apply
    fi
  '';
}

