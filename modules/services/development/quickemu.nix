# QuickEMU module
#
# Usage: modules.services.development = [ "quickemu" ]
{
  pkgs,
  ...
}:
{
  # QuickEMU for quick VM creation

  config = {
    environment.systemPackages = with pkgs; [
      quickemu
    ];
  };
}
