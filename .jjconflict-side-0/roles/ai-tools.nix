# AI tools role: install mcp-nixos and user service
{
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs; [
    mcp-nixos
    lmstudio
    # stable.open-webui
  ];

  # User service so multiple apps can rely on a persistent MCP instance
  systemd.user.services."mcp-nixos" = {
    description = "MCP server for NixOS (mcp-nixos)";
    wantedBy = ["default.target"];
    after = ["network-online.target"];
    serviceConfig = {
      ExecStart = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      Restart = "on-failure";
      RestartSec = 2;
      # Keep logs in journal; no stdin required
      StandardInput = "null";
      WorkingDirectory = "%h";
    };
  };
}
