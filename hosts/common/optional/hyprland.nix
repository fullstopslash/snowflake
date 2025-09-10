{ inputs, pkgs, ... }:
{
  programs.hyprland = {
    enable = true;
    package = pkgs.unstable.hyprland;
  };

  environment.systemPackages = [
    inputs.rose-pine-hyprcursor.packages.${pkgs.system}.default
  ];
}
