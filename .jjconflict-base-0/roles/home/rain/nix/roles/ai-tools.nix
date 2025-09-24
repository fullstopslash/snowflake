{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    mcp-nixos
  ];
}
