# SOPS configuration module
{inputs, ...}: {
  # SOPS configuration
  sops = {
    defaultSopsFile = inputs.nix-secrets.outPath + "/sops/shared.yaml";

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
