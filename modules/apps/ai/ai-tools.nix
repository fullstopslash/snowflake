# AI tools module: install various AI development tools
#
# Usage: modules.apps.ai = [ "ai-tools" ]
{ config, pkgs, ... }:
let
  ollamaCfg = config.services.ollama;
in
{
  # AI development tools (aider, aichat)
  config = {
    environment.systemPackages = with pkgs; [
      aider-chat
      aichat
    ];

    # Environment variables for AI tool integration
    environment.sessionVariables = {
      OLLAMA_HOST = "${ollamaCfg.host}:${toString ollamaCfg.port}";
    };
  };
}
