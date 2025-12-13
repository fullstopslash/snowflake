# AI tools role: install various AI development tools
# FIXME: Many packages require custom overlays or flake inputs - commented out until added
{ pkgs, config, ... }:
let
  ollamaCfg = config.services.ollama;
in
{
  environment.systemPackages = with pkgs; [
    # Available in nixpkgs
    aider-chat
    aichat
  ];

  # Environment variables for AI tool integration
  # References the ollama config to stay in sync
  environment.sessionVariables = {
    OLLAMA_HOST = "${ollamaCfg.host}:${toString ollamaCfg.port}";
  };
}
