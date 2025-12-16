# SOPS configuration module
# Sets defaults for sops-nix. sops-nix is imported at flake level for all hosts.
# Host-specific secrets are configured in hosts/common/core/sops.nix
{
  config,
  lib,
  ...
}:
{
  sops = {
    # defaultSopsFile should be set per-host in hosts/common/core/sops.nix

    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      # Allow decryption using the machine's SSH host key (age recipient derived via ssh-to-age)
      sshKeyPaths = [
        "/etc/ssh/ssh_host_ed25519_key"
      ];
      generateKey = true;
    };

    # Secrets configuration disabled for now - needs defaultSopsFile to be set per-host
    # secrets = lib.mkIf (config.hostSpec.hasSecrets && config.sops.defaultSopsFile != null) {
    #   # Track when host age key was generated (for rotation scheduling)
    #   "sops/key-metadata" = {
    #     sopsFile = "${builtins.dirOf config.sops.defaultSopsFile}/${config.networking.hostName}.yaml";
    #     mode = "0400";
    #     # Content in secret: { "generated_at": "2025-12-15", "rotated_at": null }
    #   };
    # };
  };

  # Activation script to create metadata if missing
  system.activationScripts.sopsKeyMetadata = lib.mkIf config.hostSpec.hasSecrets ''
    KEY_METADATA="/run/secrets/sops/key-metadata"
    KEY_FILE="/var/lib/sops-nix/key.txt"

    if [ -f "$KEY_FILE" ] && [ ! -f "$KEY_METADATA" ]; then
      # Key exists but no metadata - likely pre-existing system
      # Get key file creation date as best estimate
      KEY_DATE=$(stat -c %Y "$KEY_FILE")
      KEY_DATE_ISO=$(date -d "@$KEY_DATE" +%Y-%m-%d)

      echo "Warning: No key metadata found. Estimated generation date: $KEY_DATE_ISO"
      echo "Run 'just sops-init-key-metadata' to add tracking to nix-secrets"
    fi
  '';
}
