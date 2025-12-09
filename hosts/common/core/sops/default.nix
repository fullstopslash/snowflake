# Role-based sops secrets configuration
#
# This module orchestrates secret categories based on hostSpec.secretCategories.
# Each category is a separate module that only activates when its category is enabled.
#
# Categories:
# - base: user passwords, age keys, msmtp (default: true)
# - desktop: home assistant, desktop app secrets (set by desktop/laptop roles)
# - server: backup credentials, service secrets (set by server role)
# - network: tailscale, VPN configs (set by roles with networking needs)
#
# Bootstrap notes:
# - New hosts need their SSH host key generated BEFORE first rebuild with secrets
# - The age key is derived from /etc/ssh/ssh_host_ed25519_key automatically
# - Run scripts/bootstrap-nixos.sh to set up keys, or manually:
#   1. Generate host key: ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ''
#   2. Get age key: cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
#   3. Add to nix-secrets/.sops.yaml and rekey
#
# sops-nix module is imported at flake level so all hosts have access to sops options.

{
  lib,
  inputs,
  config,
  ...
}:
let
  sopsFolder = builtins.toString inputs.nix-secrets + "/sops";
  hasSecrets = config.hostSpec.hasSecrets;
  hostName = config.hostSpec.hostName;
  hostSecretsFile = "${sopsFolder}/${hostName}.yaml";
  sharedSecretsFile = "${sopsFolder}/shared.yaml";
in
{
  imports = [
    ./base.nix
    ./desktop.nix
    ./server.nix
    ./network.nix
    ./shared.nix
  ];

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
    warnings = lib.optional
      (builtins.pathExists hostSecretsFile && builtins.readFile hostSecretsFile == "{}\n")
      "SOPS: ${hostName}.yaml appears to be empty. Did you forget to add secrets?";
  };
}
