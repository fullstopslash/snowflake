# Install starship-jj from its flake
# Temporarily disabled due to upstream build issue: missing 'insta' dependency
# See: https://gitlab.com/lanastara_foss/starship-jj
{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = [
    inputs.starship-jj.packages."${pkgs.stdenv.hostPlatform.system}".default
  ];
}
