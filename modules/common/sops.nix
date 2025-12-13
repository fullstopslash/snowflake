# SOPS configuration module
# Sets defaults for sops-nix. sops-nix is imported at flake level for all hosts.
# Host-specific secrets are configured in hosts/common/core/sops.nix
_: {
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
  };
}
