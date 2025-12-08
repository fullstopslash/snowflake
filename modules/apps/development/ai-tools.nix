# AI tools role: install various AI development tools
# FIXME: Many packages require custom overlays or flake inputs - commented out until added
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Available in nixpkgs
    aider-chat
    aichat
  ];

  # Environment variables for AI tool integration
  environment.sessionVariables = {
    OLLAMA_HOST = "localhost:11434";
  };
}
