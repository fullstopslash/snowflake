# QuickEMU module
#
# Usage: modules.services.development = [ "quickemu" ]
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.services.development.quickemu;
in
{
  options.myModules.services.development.quickemu = {
    enable = lib.mkEnableOption "QuickEMU for quick VM creation";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      quickemu
    ];
  };
}
