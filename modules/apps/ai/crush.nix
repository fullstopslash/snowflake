# Crush AI coding agent role
# FIXME: Requires nix-ai-tools flake input - disabled until added
{ config, lib, ... }:
let
  cfg = config.myModules.apps.ai.crush;
  ollamaCfg = config.services.ollama;
  ollamaUrl = "http://${ollamaCfg.host}:${toString ollamaCfg.port}";
in
{
  options.myModules.apps.ai.crush = {
    enable = lib.mkEnableOption "Crush AI coding agent";
  };

  config = lib.mkIf cfg.enable {
    # Disabled: nix-ai-tools flake input not available
    # environment.systemPackages = with inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}; [
    #   crush
    # ];

    # Provide default config that points to local Ollama service
    # User config in ~/.config/crush/crush.json will override this
    environment.etc."crush/crush.json".text = builtins.toJSON {
      # Ollama backend configuration
      backend = "ollama";
      ollama = {
        base_url = ollamaUrl;
        model = "llama3.2"; # User can override with: crush --model <name>
      };
    };

    # Environment variable fallback (Crush may also respect this)
    # NOTE: OLLAMA_HOST is set in modules/apps/development/ai-tools.nix
    environment.sessionVariables = {
      CRUSH_BACKEND = "ollama";
    };
  };
}
