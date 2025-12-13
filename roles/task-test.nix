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
{
  config = lib.mkIf (builtins.elem "test" config.roles) {
    # Test VMs need sops passwords, so override isMinimal from VM role
    hostSpec.isMinimal = lib.mkForce false;

    # Enable CLI secret category for atuin credentials
    hostSpec.secretCategories.cli = lib.mkDefault true;

    # Test-friendly settings (use plain values to override mkDefault in base modules)
    security.sudo.wheelNeedsPassword = false;
    services.openssh.settings.PasswordAuthentication = true;
    services.openssh.settings.PermitRootLogin = "yes";
    documentation.enable = false;

    # Auto-clone nix-config and nix-secrets repos on first login
    # (path is in modules/common/ so not part of selection system)
    myModules.services.nixConfigRepo.enable = true;

    # Atuin shell history sync with auto-login
    myModules.services.cli.atuin.enable = true;

    # Syncthing file sync with device IDs from nix-secrets
    myModules.services.networking.syncthing.enable = true;

    # Useful apps for test VMs
    environment.systemPackages = with pkgs; [
      firefox
    ];
  };
}
