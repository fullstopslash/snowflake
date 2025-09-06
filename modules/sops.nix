# SOPS configuration module
_: {
  # SOPS configuration
  sops = {
    defaultSopsFile = ../secrets.yaml;

    age = {
      keyFile = "/home/rain/.config/sops/age/keys.txt";
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
