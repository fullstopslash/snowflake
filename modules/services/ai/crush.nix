# Crush AI coding agent role
# FIXME: Requires nix-ai-tools flake input - disabled until added
{ ... }:
{
  # Disabled: nix-ai-tools flake input not available
  # environment.systemPackages = with inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}; [
  #   crush
  # ];

  # Provide default config that points to local Ollama Docker service
  # User config in ~/.config/crush/crush.json will override this
  environment.etc."crush/crush.json".text = builtins.toJSON {
    # Ollama backend configuration
    backend = "ollama";
    ollama = {
      base_url = "http://localhost:11434";
      model = "llama3.2"; # User can override with: crush --model <name>
    };
  };

  # Environment variable fallback (Crush may also respect this)
  environment.sessionVariables = {
    CRUSH_BACKEND = "ollama";
    OLLAMA_HOST = "localhost:11434";
  };
}
