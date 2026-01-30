# Ollama role with ROCm support for AMD GPUs
{
  pkgs,
  config,
  ...
}: {
  # services.llama-cpp = {
  #   enable = true;
  # };
  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    host = "127.0.0.1";
    port = 11434;
    rocmOverrideGfx = "11.0.0";
  };

  # Ensure Ollama service has access to ROCm devices and environment variables
  # systemd.services.ollama = {
  #   # Grant access to ROCm device files for AMD GPU acceleration
  #   package = pkgs.ollama-vulkan;
  #   serviceConfig = {
  #     SupplementaryGroups = ["render" "video"];
  #     # Enable GPU acceleration via ROCm for AMD GPUs
  #     # Ollama auto-detects ROCm if libraries are available
  #     Environment = [
  #       "HIP_VISIBLE_DEVICES=all"
  #       "HSA_OVERRIDE_GFX_VERSION_1=11.0.0"
  #     ];
  #   };
  # };

  # Make ollama CLI available in PATH
  environment.systemPackages = [pkgs.llama-cpp-rocm];

  # Allow firewall access to Ollama port (references configured port)
  networking.firewall.allowedTCPPorts = [config.services.ollama.port];
}
