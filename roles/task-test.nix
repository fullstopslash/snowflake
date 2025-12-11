# Test role - settings for test/development VMs (composable task role)
#
# Can be combined with any hardware role: roles.vm + roles.test
# Enables: passwordless sudo, SSH password auth, auto-clone repos, Firefox, Atuin, Syncthing
# Disables: documentation
#
# This is a task-based role, not mutually exclusive with hardware roles.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.roles;
in
{
  config = lib.mkIf cfg.test {
    # Test VMs need sops passwords, so override isMinimal from VM role
    hostSpec.isMinimal = lib.mkForce false;

    # Test-friendly settings (use plain values to override mkDefault in base modules)
    security.sudo.wheelNeedsPassword = false;
    services.openssh.settings.PasswordAuthentication = true;
    services.openssh.settings.PermitRootLogin = "yes";
    documentation.enable = false;

    # Auto-clone nix-config and nix-secrets repos on first login
    myModules.services.nixConfigRepo.enable = true;

    # Useful apps for test VMs
    environment.systemPackages = with pkgs; [
      firefox
      atuin
    ];

    # Syncthing for file sync
    services.syncthing = {
      enable = true;
      user = config.hostSpec.primaryUsername;
      dataDir = "/home/${config.hostSpec.primaryUsername}";
    };
  };
}
