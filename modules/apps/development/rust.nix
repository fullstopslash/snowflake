# Install starship-jj from its flake
# FIXME: Requires starship-jj flake input - disabled until added
{ ... }:
{
  # Disabled: starship-jj flake input not available
  # environment.systemPackages = [
  #   inputs.starship-jj.packages."${pkgs.stdenv.hostPlatform.system}".default
  # ];
}
