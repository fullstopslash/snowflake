# Test role - settings for headless test/development VMs (composable task role)
#
# Can be combined with any hardware role: roles.vmHeadless + roles.test
# Enables: passwordless sudo, SSH password auth, auto-clone repos, Atuin, essential networking
# Disables: documentation, desktop environments
#
# This is a task-based role, not mutually exclusive with hardware roles.
{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (builtins.elem "test" config.roles) {
    # ========================================
    # MODULE SELECTIONS
    # ========================================
    # Paths mirror filesystem: modules/<top>/<category> = [ "<module>" ]
    modules = {
      services = {
        cli = [ "atuin" ];
        networking = [
          "openssh"
          "ssh"
          "syncthing"
          "tailscale"
        ];
      };
    };

    # ========================================
    # AUTO-UPGRADE (for testing GitOps workflow)
    # ========================================
    # Frequent auto-upgrade for rapid testing iteration
    # Validates critical services before accepting the upgrade
    myModules.services.autoUpgrade = {
      enable = lib.mkDefault true;
      mode = lib.mkDefault "local";
      schedule = lib.mkDefault "hourly"; # Frequent for rapid testing iteration
      buildBeforeSwitch = lib.mkDefault true;
      validationChecks = lib.mkDefault [
        # Ensure critical services are enabled
        "systemctl --quiet is-enabled sshd"
        "systemctl --quiet is-enabled tailscaled"
      ];
      onValidationFailure = lib.mkDefault "rollback"; # Safest option
    };

    # ========================================
    # GOLDEN GENERATION (boot safety testing)
    # ========================================
    # Auto-pin after successful boot to test golden generation workflow
    myModules.system.goldenGeneration = {
      enable = lib.mkDefault true;
      validateServices = lib.mkDefault [
        "sshd.service"
        "tailscaled.service"
      ];
      autoPinAfterBoot = lib.mkDefault true; # Auto-pin for testing golden generation workflow
    };

    # ========================================
    # CHEZMOI DOTFILE SYNC (for testing GitOps workflow)
    # ========================================
    # Enable chezmoi-sync to test jj-based conflict-free dotfile management
    myModules.services.dotfiles.chezmoiSync = {
      enable = lib.mkDefault true;
      repoUrl = lib.mkDefault "git@github.com:fullstopslash/dotfiles.git";
      autoCommit = lib.mkDefault true;
      autoPush = lib.mkDefault true;
    };

    # Enable CLI secret category for atuin credentials
    sops.categories.cli = lib.mkDefault true;

    # Test-friendly settings (use plain values to override mkDefault in base modules)
    security.sudo.wheelNeedsPassword = false;
    services.openssh.settings.PasswordAuthentication = true;
    services.openssh.settings.PermitRootLogin = "yes";
    documentation.enable = false;

    # Auto-clone nix-config and nix-secrets repos on first login
    # (path is in modules/common/ so not part of selection system)
    myModules.services.nixConfigRepo.enable = true;
  };
}
