# Crush AI coding agent role
{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    # Crush from nix-ai-tools flake
    inputs.nix-ai-tools.packages.x86_64-linux.crush
  ];

  # Optional: Add any system-wide configuration if needed
  # Most Crush config is user-specific in ~/.config/crush/crush.json
}
