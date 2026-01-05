# GitHub repository deployment module
#
# Deploys GitHub deploy keys from SOPS and ensures repos are cloned on first boot.
# Uses per-repo SSH host aliases to work around GitHub's deploy key restrictions.
#
# Usage: modules.services.development = [ "github-repos" ]
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  sopsFolder = builtins.toString inputs.nix-secrets + "/sops";
  hostname = config.networking.hostName;
  primaryUser = config.identity.primaryUsername;

  # Determine home directory based on impermanence
  homeDir =
    if config.fileSystems."/persist" or null != null then
      "/persist/home/${primaryUser}"
    else
      "/home/${primaryUser}";

  # Check if deploy keys exist in host's SOPS file
  # This allows VMs/test hosts to use deploy keys without needing an enable option
  hostSopsFile = sopsFolder + "/${hostname}.yaml";
  hasDeployKeys =
    builtins.pathExists hostSopsFile
    && builtins.match ".*deploy-keys.*" (builtins.readFile hostSopsFile) != null;
in
{
  description = "GitHub deploy keys and repository management";

  config = lib.mkIf (config.sops.defaultSopsFile or null != null) {
    # Always configure SSH for GitHub (critical for flake updates)
    # Personal SSH key is always configured for general GitHub access
    programs.ssh.extraConfig = ''
      # Personal SSH key for general GitHub access
      # Deployed by ssh.nix to /run/secrets/keys/ssh/ed25519
      Host github.com
          HostName github.com
          User git
          IdentityFile /run/secrets/keys/ssh/ed25519
          StrictHostKeyChecking accept-new

      # Per-repo deploy key aliases (used by github-repos-init service)
      # These will only work if deploy keys are deployed
      Host github.com-nix-config
          HostName github.com
          User git
          IdentityFile ${homeDir}/.ssh/nix-config-deploy
          StrictHostKeyChecking accept-new

      Host github.com-nix-secrets
          HostName github.com
          User git
          IdentityFile ${homeDir}/.ssh/nix-secrets-deploy
          StrictHostKeyChecking accept-new

      Host github.com-chezmoi
          HostName github.com
          User git
          IdentityFile ${homeDir}/.ssh/chezmoi-deploy
          StrictHostKeyChecking accept-new
    '';

    # Deploy keys from SOPS to user's .ssh directory (only if they exist in SOPS)
    sops.secrets = lib.mkIf hasDeployKeys {
      # Per-host deploy keys for repository-specific access
      "deploy-keys/nix-config" = {
        sopsFile = "${sopsFolder}/${hostname}.yaml";
        owner = primaryUser;
        path = "${homeDir}/.ssh/nix-config-deploy";
        mode = "0400";
      };
      "deploy-keys/nix-secrets" = {
        sopsFile = "${sopsFolder}/${hostname}.yaml";
        owner = primaryUser;
        path = "${homeDir}/.ssh/nix-secrets-deploy";
        mode = "0400";
      };
      "deploy-keys/chezmoi" = {
        sopsFile = "${sopsFolder}/${hostname}.yaml";
        owner = primaryUser;
        path = "${homeDir}/.ssh/chezmoi-deploy";
        mode = "0400";
      };
    };

    # Systemd services for repo cloning (only if deploy keys enabled)
    systemd.services = lib.mkIf hasDeployKeys {
      github-repos-init = {
        description = "Clone GitHub repos to user home on first boot";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network-online.target"
          "sops-nix.service"
        ];
        wants = [ "network-online.target" ];

        # Only run if repos don't exist
        unitConfig = {
          ConditionPathExists = "!${homeDir}/nix-config/.git";
        };

        path = [
          pkgs.git
          pkgs.openssh
          pkgs.util-linux
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = primaryUser;
          Group = "users";
          Environment = "HOME=${homeDir}";
        };

        script = ''
          set -euo pipefail

          log() {
            echo "[github-repos-init] $*"
            logger -t github-repos-init "$*"
          }

          log "Starting GitHub repository cloning to ${homeDir}..."

          # Verify SSH keys exist before attempting clones
          for key in nix-config-deploy nix-secrets-deploy chezmoi-deploy; do
            if [ ! -f ${homeDir}/.ssh/$key ]; then
              log "ERROR: Deploy key not found: ${homeDir}/.ssh/$key"
              log "SOPS secrets may not have been deployed yet"
              exit 1
            fi
          done

          log "All SSH keys verified - ready to clone"

          # Create directories if needed
          mkdir -p ${homeDir}/.local/share

          # Clone function with retry logic
          clone_repo() {
            local name=$1
            local alias=$2
            local url=$3
            local dest=$4
            local max_retries=3
            local retry_delay=5

            if [ -d "$dest/.git" ]; then
              log "Repository $name already cloned at $dest"
              return 0
            fi

            log "Cloning $name..."
            log "  URL: $url"
            log "  Destination: $dest"

            for attempt in $(seq 1 $max_retries); do
              log "Attempt $attempt/$max_retries..."

              # Test SSH connection first
              if ssh -o ConnectTimeout=10 -o BatchMode=yes -T git@$alias 2>&1 | grep -q "successfully authenticated\|Hi fullstopslash"; then
                log "SSH connection to $alias successful"
              else
                log "WARNING: SSH connection test to $alias failed, but attempting clone anyway..."
              fi

              # Attempt clone with verbose SSH
              if GIT_SSH_COMMAND="ssh -v" ${pkgs.git}/bin/git clone git@$alias:$url "$dest" 2>&1 | tee /tmp/git-clone-$name.log; then
                log "Successfully cloned $name"
                return 0
              else
                log "Clone failed (attempt $attempt/$max_retries)"
                cat /tmp/git-clone-$name.log | tail -20 | while read line; do
                  log "  $line"
                done

                if [ $attempt -lt $max_retries ]; then
                  log "Retrying in $retry_delay seconds..."
                  sleep $retry_delay
                  retry_delay=$((retry_delay * 2))
                fi
              fi
            done

            log "ERROR: Failed to clone $name after $max_retries attempts"
            return 1
          }

          # Clone all three repos
          clone_repo "nix-config" "github.com-nix-config" "fullstopslash/snowflake.git" "${homeDir}/nix-config"
          clone_repo "nix-secrets" "github.com-nix-secrets" "fullstopslash/snowflake-secrets.git" "${homeDir}/nix-secrets"
          clone_repo "chezmoi" "github.com-chezmoi" "fullstopslash/dotfiles.git" "${homeDir}/.local/share/chezmoi"

          log "All repositories cloned successfully"
        '';
      };

      # Chezmoi initialization service - runs after repos are cloned
      chezmoi-init = {
        description = "Initialize chezmoi dotfiles on first boot";
        wantedBy = [ "multi-user.target" ];
        after = [ "github-repos-init.service" ];
        wants = [ "github-repos-init.service" ];

        # Only run if chezmoi hasn't been initialized yet
        # Note: Don't check for repo existence here - systemd evaluates conditions
        # before dependencies run. The script waits for the repo to be cloned.
        unitConfig = {
          ConditionPathExists = "!${homeDir}/.chezmoi-initialized";
        };

        path = [
          pkgs.chezmoi
          pkgs.util-linux
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = primaryUser;
          Group = "users";
          Environment = "HOME=${homeDir}";
        };

        script = ''
          set -euo pipefail

          log() {
            echo "[chezmoi-init] $*"
            logger -t chezmoi-init "$*"
          }

          log "Initializing chezmoi dotfiles..."

          # Wait for chezmoi repo to exist (in case service starts before clone completes)
          for i in {1..30}; do
            if [ -d ${homeDir}/.local/share/chezmoi/.git ]; then
              log "Chezmoi repository found"
              break
            fi
            log "Waiting for chezmoi repository... ($i/30)"
            sleep 2
          done

          if [ ! -d ${homeDir}/.local/share/chezmoi/.git ]; then
            log "ERROR: Chezmoi repository not found after waiting"
            exit 1
          fi

          # Initialize chezmoi (doesn't apply yet)
          log "Running chezmoi init..."
          ${pkgs.chezmoi}/bin/chezmoi init || true

          # Apply dotfiles
          log "Applying chezmoi dotfiles..."
          if ${pkgs.chezmoi}/bin/chezmoi apply --force 2>&1 | tee /tmp/chezmoi-apply.log; then
            log "Chezmoi dotfiles applied successfully"
          else
            log "WARNING: Chezmoi apply had issues:"
            cat /tmp/chezmoi-apply.log | tail -20 | while read line; do
              log "  $line"
            done
          fi

          # Create marker file
          touch ${homeDir}/.chezmoi-initialized
          log "Chezmoi initialization complete"
        '';
      };
    }; # end systemd.services (lib.mkIf hasDeployKeys)
  }; # end config
}
