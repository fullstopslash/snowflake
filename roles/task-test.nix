# Test role - settings for test/development VMs (composable task role)
#
# Can be combined with any hardware role: roles.vm + roles.test
# Enables: passwordless sudo, SSH password auth, auto-clone repos
# Disables: documentation
#
# This is a task-based role, not mutually exclusive with hardware roles.
{ config, lib, ... }:
let
  cfg = config.roles;
in
{
  config = lib.mkIf cfg.test {
    # Test-friendly settings (use plain values to override mkDefault in base modules)
    security.sudo.wheelNeedsPassword = false;
    services.openssh.settings.PasswordAuthentication = true;
    services.openssh.settings.PermitRootLogin = "yes";
    documentation.enable = false;

    # Auto-clone nix-config and nix-secrets repos on first login
    myModules.services.nixConfigRepo.enable = true;
  };
}
