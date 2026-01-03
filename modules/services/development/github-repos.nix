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
    if config.fileSystems."/persist" or null != null
    then "/persist/home/${primaryUser}"
    else "/home/${primaryUser}";
in
{
  description = "GitHub deploy keys and repository management";

  options = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable GitHub deploy key deployment and repo cloning";
    };
  };

  config = lib.mkIf (config.sops.defaultSopsFile or null != null) {
    # Deploy keys from SOPS to root's .ssh directory
    sops.secrets = {
      "deploy-keys/nix-config" = {
        sopsFile = "${sopsFolder}/${hostname}.yaml";
        owner = "root";
        path = "/root/.ssh/nix-config-deploy";
        mode = "0400";
      };
      "deploy-keys/nix-secrets" = {
        sopsFile = "${sopsFolder}/${hostname}.yaml";
        owner = "root";
        path = "/root/.ssh/nix-secrets-deploy";
        mode = "0400";
      };
      "deploy-keys/chezmoi" = {
        sopsFile = "${sopsFolder}/${hostname}.yaml";
        owner = "root";
        path = "/root/.ssh/chezmoi-deploy";
        mode = "0400";
      };
    };

    # Configure SSH with per-repo host aliases
    # GitHub doesn't allow the same deploy key on multiple repos,
    # and SSH connection multiplexing reuses the first connection.
    # Per-repo aliases force separate connections with different keys.
    programs.ssh.extraConfig = ''
      Host github.com-nix-config
          HostName github.com
          User git
          IdentityFile /root/.ssh/nix-config-deploy
          StrictHostKeyChecking accept-new

      Host github.com-nix-secrets
          HostName github.com
          User git
          IdentityFile /root/.ssh/nix-secrets-deploy
          StrictHostKeyChecking accept-new

      Host github.com-chezmoi
          HostName github.com
          User git
          IdentityFile /root/.ssh/chezmoi-deploy
          StrictHostKeyChecking accept-new
    '';

    # Systemd service to clone repos on first boot
    systemd.services.github-repos-init = {
      description = "Clone GitHub repos to user home on first boot";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "sops-nix.service" ];
      wants = [ "network-online.target" ];

      # Only run if repos don't exist
      unitConfig = {
        ConditionPathExists = "!${homeDir}/nix-config/.git";
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
      };

      script = ''
        set -euo pipefail

        echo "Cloning GitHub repos to ${homeDir}..."

        # Create home directory if needed
        mkdir -p ${homeDir}

        # Clone repos using per-repo aliases
        if [ ! -d ${homeDir}/nix-config/.git ]; then
          echo "Cloning nix-config..."
          ${pkgs.git}/bin/git clone git@github.com-nix-config:fullstopslash/snowflake.git ${homeDir}/nix-config
        fi

        if [ ! -d ${homeDir}/nix-secrets/.git ]; then
          echo "Cloning nix-secrets..."
          ${pkgs.git}/bin/git clone git@github.com-nix-secrets:fullstopslash/snowflake-secrets.git ${homeDir}/nix-secrets
        fi

        if [ ! -d ${homeDir}/.local/share/chezmoi/.git ]; then
          echo "Cloning chezmoi..."
          mkdir -p ${homeDir}/.local/share
          ${pkgs.git}/bin/git clone git@github.com-chezmoi:fullstopslash/dotfiles.git ${homeDir}/.local/share/chezmoi
        fi

        # Fix ownership
        chown -R ${primaryUser}:users ${homeDir}

        echo "All repos cloned successfully"
      '';
    };
  };
}
