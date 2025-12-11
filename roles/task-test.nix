# Test role - settings for test/development VMs (composable task role)
#
# Can be combined with any hardware role: roles.vm + roles.test
# Enables: passwordless sudo, SSH password auth
# Disables: documentation
#
# This is a task-based role, not mutually exclusive with hardware roles.
{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  config = lib.mkIf cfg.test {
    # Test-friendly settings
    security.sudo.wheelNeedsPassword = lib.mkDefault false;
    services.openssh.settings.PasswordAuthentication = lib.mkDefault true;
    services.openssh.settings.PermitRootLogin = lib.mkDefault "yes";
    documentation.enable = lib.mkDefault false;
  };
}
