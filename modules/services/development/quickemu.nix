# QuickEMU module
#
# Usage: modules.services.development = [ "quickemu" ]
{
  pkgs,
  ...
}:
{
  description = "QuickEMU for quick VM creation";

  config = {
    environment.systemPackages = with pkgs; [
      quickemu
    ];
  };
}
