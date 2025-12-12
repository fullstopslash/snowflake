# Core SOPS secrets configuration
#
# This module provides the foundational sops-nix setup for all hosts with secrets.
# It includes:
# - Core sops config (defaultSopsFile, age key paths)
# - Base secrets (user password, age key, msmtp) needed for any host
#
# Service-specific secrets are defined in their respective modules:
# - Tailscale: modules/services/networking/tailscale.nix
# - Atuin: modules/services/cli/atuin.nix
# - HASS: modules/services/desktop/common.nix
# - Borg: modules/services/storage/borg.nix
#
# Bootstrap notes:
# - New hosts need their SSH host key generated BEFORE first rebuild with secrets
# - The age key is derived from /etc/ssh/ssh_host_ed25519_key automatically
# - Run scripts/bootstrap-nixos.sh to set up keys, or manually:
#   1. Generate host key: ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ''
#   2. Get age key: cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
#   3. Add to nix-secrets/.sops.yaml and rekey
{
  lib,
  inputs,
  config,
  ...
}:
let
  sopsFolder = builtins.toString inputs.nix-secrets + "/sops";
  hasSecrets = config.hostSpec.hasSecrets;
  baseEnabled = config.hostSpec.secretCategories.base or true;
  hostName = config.hostSpec.hostName;
  hostSecretsFile = "${sopsFolder}/${hostName}.yaml";
  sharedSecretsFile = "${sopsFolder}/shared.yaml";
in
{
  config = lib.mkIf hasSecrets {
    # Assertions to catch bootstrap issues early
    assertions = [
      {
        assertion = builtins.pathExists hostSecretsFile;
        message = ''
          SOPS: Host secrets file not found: ${hostSecretsFile}

          To bootstrap secrets for ${hostName}:
          1. Run: scripts/bootstrap-nixos.sh -n ${hostName} -d <ip> -k <ssh-key>
          2. Or manually create the file in nix-secrets/sops/${hostName}.yaml

          If this is a new host, you may need to:
          - Generate the host age key from SSH key
          - Add the key to nix-secrets/.sops.yaml
          - Run 'just rekey' in nix-secrets
          - Update flake: nix flake update nix-secrets
        '';
      }
      {
        assertion = builtins.pathExists sharedSecretsFile;
        message = ''
          SOPS: Shared secrets file not found: ${sharedSecretsFile}

          The shared.yaml file should exist in nix-secrets/sops/.
          This file contains secrets shared across all hosts (passwords, etc).
        '';
      }
    ];

    # Core sops configuration - always set when hasSecrets is true
    sops = {
      defaultSopsFile = hostSecretsFile;
      validateSopsFiles = false;
      age = {
        # automatically import host SSH keys as age keys
        sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      };
    };

    # Helpful warning if secrets directory is empty
    warnings = lib.optional (
      builtins.pathExists hostSecretsFile && builtins.readFile hostSecretsFile == "{}\n"
    ) "SOPS: ${hostName}.yaml appears to be empty. Did you forget to add secrets?";

    # Base secrets - enabled by default for all hosts with secrets
    sops.secrets = lib.mkIf baseEnabled (
      {
        # Age key for home-manager sops - stored in host-specific file (default sopsFile)
        "keys/age" = {
          # No sopsFile specified - uses default host-specific file
          owner = config.users.users.${config.hostSpec.username}.name;
          inherit (config.users.users.${config.hostSpec.username}) group;
          path = "${config.hostSpec.home}/.config/sops/age/keys.txt";
        };

        # User password for login
        "passwords/${config.hostSpec.username}" = {
          sopsFile = sharedSecretsFile;
          neededForUsers = true;
        };

        # msmtp password for system mail
        "passwords/msmtp" = {
          sopsFile = sharedSecretsFile;
        };
      }
      # SSH key for non-yubikey hosts (VMs, servers) - needed for GitHub access (chezmoi, etc.)
      // lib.optionalAttrs (!config.hostSpec.useYubikey) {
        "keys/ssh/ed25519" = {
          sopsFile = sharedSecretsFile;
          owner = config.users.users.${config.hostSpec.username}.name;
          inherit (config.users.users.${config.hostSpec.username}) group;
          path = "${config.hostSpec.home}/.ssh/id_ed25519";
          mode = "0600";
        };
      }
    );

    # Fix ownership of .config/sops directory
    system.activationScripts.sopsSetAgeKeyOwnership = lib.mkIf baseEnabled (
      let
        ageFolder = "${config.hostSpec.home}/.config/sops/age";
        user = config.users.users.${config.hostSpec.username}.name;
        group = config.users.users.${config.hostSpec.username}.group;
      in
      ''
        mkdir -p ${ageFolder} || true
        chown -R ${user}:${group} ${config.hostSpec.home}/.config
      ''
    );

    # Create .ssh directory with correct permissions for SSH key deployment
    system.activationScripts.sopsSetSshDirOwnership =
      lib.mkIf (baseEnabled && !config.hostSpec.useYubikey)
        (
          let
            sshFolder = "${config.hostSpec.home}/.ssh";
            user = config.users.users.${config.hostSpec.username}.name;
            group = config.users.users.${config.hostSpec.username}.group;
          in
          ''
            mkdir -p ${sshFolder} || true
            chmod 700 ${sshFolder}
            chown ${user}:${group} ${sshFolder}
          ''
        );
  };
}
