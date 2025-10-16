# Install starship-jj from its flake
{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = [
    inputs.starship-jj.packages."${pkgs.system}".default
  ];
}
