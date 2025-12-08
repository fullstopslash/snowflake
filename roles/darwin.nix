{
  config,
  lib,
  ...
}:
let
  cfg = config.roles;
in
{
  # macOS - placeholder for T2 MacBook
  # Note: Darwin uses nix-darwin, not NixOS modules

  config = lib.mkIf cfg.darwin {
    # For now, just document intended behavior
    # Actual implementation requires nix-darwin integration

    warnings = [
      "Darwin role is a placeholder - requires nix-darwin integration"
    ];
  };
}
