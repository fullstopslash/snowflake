# Ollama role with ROCm support for AMD GPUs
{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.myModules.services.ai.ollama;
in
{
  options.myModules.services.ai.ollama = {
    enable = lib.mkEnableOption "Ollama with ROCm support";
  };

  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      package = pkgs.ollama;
      host = "127.0.0.1";
      port = 11434;
    };

    # Ensure Ollama service has access to ROCm devices and environment variables
    systemd.services.ollama = {
      # Grant access to ROCm device files for AMD GPU acceleration
      serviceConfig = {
        SupplementaryGroups = [
          "render"
          "video"
        ];
        # Enable GPU acceleration via ROCm for AMD GPUs
        # Ollama auto-detects ROCm if libraries are available
        Environment = [
          "HIP_VISIBLE_DEVICES=all"
        ];
      };
    };

    # Make ollama CLI available in PATH
    environment.systemPackages = [ pkgs.ollama ];

    # Allow firewall access to Ollama port (references configured port)
    networking.firewall.allowedTCPPorts = [ config.services.ollama.port ];
  };
}
