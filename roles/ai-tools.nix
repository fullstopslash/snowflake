# AI tools role: install mcp-nixos, crush, and user services
{
  pkgs,
  inputs,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs; [
    # mcp-nixos
    lmstudio

    # Development AI tools
    code-cursor-fhs
    claude-code
    stable.gemini-cli
    codex
    aider-chat
    crush
    # alpaca
    aichat
    opencode
    # Google Antigravity - AI-native IDE for autonomous development
    inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
    # Crush from nix-ai-tools flake (configured for Ollama)
    # inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.crush

    # Ollama alternatives and UIs
    # Terminal: Use 'ollama run <model>' for built-in chat
    # Open WebUI - Web-based interface for Ollama (lightweight, modern)
    # Can run via Docker (see commented command below) or check if nixpkgs has it
    # docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main
  ];

  # Crush config should be edited directly in ~/.config/crush/crush.json
  # Example config pointing to local Ollama Docker service:
  # {
  #   "backend": "ollama",
  #   "ollama": {
  #     "base_url": "http://localhost:11434",
  #     "model": "llama3.2"
  #   }
  # }

  # Environment variables for Crush/Ollama integration (optional fallback)
  environment.sessionVariables = {
    CRUSH_BACKEND = "ollama";
    OLLAMA_HOST = "localhost:11434";
  };

  # User service so multiple apps can rely on a persistent MCP instance
  # systemd.user.services."mcp-nixos" = {
  #   description = "MCP server for NixOS (mcp-nixos)";
  #   wantedBy = ["default.target"];
  #   after = ["network-online.target"];
  #   serviceConfig = {
  #     ExecStart = "${pkgs.mcp-nixos}/bin/mcp-nixos";
  #     Restart = "on-failure";
  #     RestartSec = 2;
  #     # Keep logs in journal; no stdin required
  #     StandardInput = "null";
  #     WorkingDirectory = "%h";
  #   };
  # };
}
