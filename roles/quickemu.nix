# QuickEMU role
{pkgs, ...}: {
  # QuickEMU packages
  environment.systemPackages = with pkgs; [
    quickemu
  ];
}
