# AI tools role: install mcp-nixos
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    mcp-nixos
  ];
}
