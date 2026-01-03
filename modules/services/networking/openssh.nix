# OpenSSH server module
{
  config,
  lib,
  ...
}:
let
  # Use port from host.networking.ports.tcp.ssh if defined, otherwise default to 22
  sshPort = config.identity.networking.ports.tcp.ssh or 22;

  # Detect if this host uses impermanence (has /persist directory)
  # Check disk layout for impermanence patterns
  hasOptinPersistence =
    if config.disks.enable then
      builtins.match ".*impermanence.*" config.disks.layout != null
    else
      false;
in
{
  # OpenSSH server

  config = {
    services.openssh = {
      enable = true;
      ports = [ sshPort ];

      settings = {
        # Harden (use mkDefault so roles/hosts can override)
        PasswordAuthentication = lib.mkDefault false;
        PermitRootLogin = lib.mkDefault "no";
        # Automatically remove stale sockets
        StreamLocalBindUnlink = lib.mkDefault "yes";
        # Allow forwarding ports to everywhere
        GatewayPorts = lib.mkDefault "clientspecified";
      };

      hostKeys = [
        {
          path = "${lib.optionalString hasOptinPersistence "/persist"}/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
    };

    # yubikey login / sudo
    security.pam = {
      rssh.enable = true;
      services.sudo.rssh = true;
    };

    networking.firewall.allowedTCPPorts = [ sshPort ];
  };
}
