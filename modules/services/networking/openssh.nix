# OpenSSH server module
{
  config,
  lib,
  ...
}:
let
  cfg = config.myModules.networking.openssh;
  sshPort = config.hostSpec.networking.ports.tcp.ssh;

  # Sops needs access to the keys before the persist dirs are even mounted; so
  # just persisting the keys won't work, we must point at /persist
  #FIXME(impermanence): refactor this to how fb did it
  hasOptinPersistence = false;
in
{
  options.myModules.networking.openssh = {
    enable = lib.mkEnableOption "OpenSSH server";
  };

  config = lib.mkIf cfg.enable {
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
