# Darwin role - macOS (placeholder)
#
# NOTE: This is a placeholder. Darwin hosts use nix-darwin, not NixOS modules.
# Actual implementation requires nix-darwin integration.
{ config, lib, ... }:
{
  # macOS - placeholder for T2 MacBook
  # Note: Darwin uses nix-darwin, not NixOS modules

  config = lib.mkIf (builtins.elem "darwin" config.roles) {
    # For now, just document intended behavior
    # Actual implementation requires nix-darwin integration

    warnings = [
      "Darwin role is a placeholder - requires nix-darwin integration"
    ];
  };
}
