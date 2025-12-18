# Rust development tools
#
# Usage: modules.apps.development = [ "rust" ]
# FIXME: Requires starship-jj flake input - disabled until added
{ pkgs, ... }:
{
  description = "Rust development tools";
  config = {
    # Disabled: starship-jj flake input not available
    # environment.systemPackages = [
    #   inputs.starship-jj.packages."${pkgs.stdenv.hostPlatform.system}".default
    # ];
  };
}
