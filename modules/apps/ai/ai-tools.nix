# AI tools module: install various AI development tools
#
# Usage: modules.apps.ai = [ "ai-tools" ]
{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.myModules.apps.ai.aiTools;
  ollamaCfg = config.services.ollama;
in
{
  options.myModules.apps.ai.aiTools = {
    enable = lib.mkEnableOption "AI development tools (aider, aichat)";
  };

  config = lib.mkIf cfg.enable {
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
