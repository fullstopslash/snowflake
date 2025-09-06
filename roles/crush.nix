# Crush AI coding agent role
{
  pkgs,
  inputs,
  ...
}: {
  # Crush from nix-ai-tools flake
  environment.systemPackages = with inputs.nix-ai-tools.packages.${pkgs.system}; [
    crush
  ];

  # Optional: Add any system-wide configuration if needed
  # Most Crush config is user-specific in ~/.config/crush/crush.json
}
