{
  config,
  pkgs,
  inputs,
  ...
}:
{
  # Install chezmoi
  home.packages = [ pkgs.chezmoi ];

  # Chezmoi config managed via SOPS (deployed at NixOS level in chezmoi-sync.nix)
  # Configuration includes template variables (email, name, etc.)

  # Ensure .ssh directory exists with correct permissions
  home.file.".ssh/.keep".text = "";

  # Symlink SSH key from NixOS sops secret to user SSH directory
  # Required for chezmoi to clone dotfiles repo via git@github.com
  # The secret is deployed by modules/services/networking/ssh.nix to /run/secrets/keys/ssh/ed25519
  home.file.".ssh/id_ed25519".source =
    config.lib.file.mkOutOfStoreSymlink "/run/secrets/keys/ssh/ed25519";

  # Add GitHub's SSH host keys to known_hosts
  home.file.".ssh/known_hosts".text = ''
    github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
    github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
    github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
  '';

  # Auto-initialize and apply chezmoi on activation
  home.activation.chezmoiInit = {
    after = [
      "writeBoundary"
      "setupSecrets" # Wait for sops to deploy SSH key
    ];
    before = [ ];
    data = ''
      echo "========================================"
      echo "Running chezmoi activation script..."
      echo "========================================"

      CHEZMOI_SOURCE="${config.home.homeDirectory}/.local/share/chezmoi"
      DOTFILES_REPO="git@github.com:fullstopslash/dotfiles.git"

      # Force chezmoi to use external git and ssh by setting PATH
      export PATH="${pkgs.git}/bin:${pkgs.openssh}/bin:$PATH"

      echo "Git version: $(${pkgs.git}/bin/git --version)"
      echo "Checking if $CHEZMOI_SOURCE exists..."

      # Check if SSH key exists
      if [ ! -f "${config.home.homeDirectory}/.ssh/id_ed25519" ]; then
        echo "⚠️  SSH key not found at ~/.ssh/id_ed25519"
        echo "   Skipping chezmoi init - run 'chezmoi init --apply $DOTFILES_REPO' after key is deployed"
        exit 0
      fi

      # Deploy chezmoi config from SOPS
      CHEZMOI_CONFIG_DIR="${config.home.homeDirectory}/.config/chezmoi"
      CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/chezmoi.yaml"
      SOPS_CHEZMOI_FILE="${inputs.nix-secrets}/sops/chezmoi.yaml"

      if [ -f "$SOPS_CHEZMOI_FILE" ]; then
        echo "Deploying chezmoi config from SOPS..."
        mkdir -p "$CHEZMOI_CONFIG_DIR"
        # Use user age key deployed to ~/.config/sops/age/keys.txt
        export SOPS_AGE_KEY_FILE="${config.home.homeDirectory}/.config/sops/age/keys.txt"
        if [ -f "$SOPS_AGE_KEY_FILE" ]; then
          ${pkgs.sops}/bin/sops -d "$SOPS_CHEZMOI_FILE" > "$CHEZMOI_CONFIG_FILE"
          chmod 600 "$CHEZMOI_CONFIG_FILE"
          echo "✅ Chezmoi config deployed"
        else
          echo "⚠️  Age key not found at $SOPS_AGE_KEY_FILE - skipping chezmoi config deployment"
          echo "   Age key will be deployed on first system activation"
        fi
      else
        echo "⚠️  SOPS chezmoi config not found at $SOPS_CHEZMOI_FILE"
      fi

      if [ ! -d "$CHEZMOI_SOURCE/.git" ]; then
        echo "Initializing chezmoi from $DOTFILES_REPO"
        if ${pkgs.chezmoi}/bin/chezmoi init --apply --force "$DOTFILES_REPO" 2>&1; then
          echo "✅ Chezmoi initialized successfully"
        else
          echo "⚠️  Chezmoi init failed - check SSH keys and repo access"
          echo "To init manually: chezmoi init --apply $DOTFILES_REPO"
        fi
      else
        echo "Chezmoi already initialized, updating..."
        ${pkgs.chezmoi}/bin/chezmoi update 2>&1 || echo "⚠️  Chezmoi update failed"
      fi

      echo "========================================"
    '';
  };
}
