# Rust development tools
#
# Usage: modules.apps.development = [ "rust" ]
# FIXME: Requires starship-jj flake input - disabled until added
{ config, lib, ... }:
let
  cfg = config.myModules.apps.development.rust;
in
{
  options.myModules.apps.development.rust = {
    enable = lib.mkEnableOption "Rust development tools";
  };

  config = lib.mkIf cfg.enable {
    # Disabled: starship-jj flake input not available
    # environment.systemPackages = [
    #   inputs.starship-jj.packages."${pkgs.stdenv.hostPlatform.system}".default
    # ];
  };
}
