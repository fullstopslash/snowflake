# Fast test role - absolute minimum for deployment testing
#
# Note: With the filesystem-driven module system, modules are only enabled
# if explicitly selected. This role provides minimal packages and disables docs.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (builtins.elem "fastTest" config.roles) {
    # Minimal test packages only
    environment.systemPackages = with pkgs; [
      git
      curl
      htop
    ];

    # Disable documentation for faster builds
    documentation.enable = false;
    documentation.man.enable = false;
    documentation.nixos.enable = false;
  };
}
