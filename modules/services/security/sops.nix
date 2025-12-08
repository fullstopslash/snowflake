# SOPS configuration module
_: {
  # SOPS configuration
  sops = {
    # defaultSopsFile should be set per-host or per-role
    # defaultSopsFile = /path/to/secrets.yaml;

    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      # Allow decryption using the machine's SSH host key (age recipient derived via ssh-to-age)
      sshKeyPaths = [
        "/etc/ssh/ssh_host_ed25519_key"
      ];
      generateKey = true;
    };
    # secrets = {
    #   rain-password = {};
    #   pain-password = {};
    # };
  };
}
