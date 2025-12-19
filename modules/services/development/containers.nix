{ config, lib, ... }:
{
  description = "Docker container configuration";

  config = {
    # Compose-style layout: write docker-compose YAML and manage via systemd
    virtualisation.docker.daemon.settings = {
      "log-driver" = "json-file";
      "log-opts" = {
        "max-size" = "50m";
        "max-file" = "3";
      };
    };
    # NOTE: Ollama Docker Compose service removed - using NixOS-managed ollama.service instead
    # (see roles/ollama.nix). Both services bind to port 11434, causing conflicts.
    # If you need Docker Ollama, disable services.ollama.enable in roles/ollama.nix and uncomment below:
    #
    # environment.etc."docker/compose/ollama/docker-compose.yml".text = ''
    #   version: "3.9"
    #   services:
    #     ollama:
    #       image: ollama/ollama:rocm
    #       container_name: ollama
    #       restart: unless-stopped
    #       ports:
    #         - "11434:11434"
    #       volumes:
    #         - ollama:/root/.ollama
    #       devices:
    #         - "/dev/kfd:/dev/kfd"
    #         - "/dev/dri:/dev/dri"
    #   volumes:
    #     ollama: {}
    # '';
    #
    # systemd.services."docker-compose-ollama" = {
    #   description = "Docker Compose: Ollama (ROCm)";
    #   after = ["network-online.target"];
    #   wants = ["network-online.target"];
    #   wantedBy = ["multi-user.target"];
    #   serviceConfig = {
    #     Type = "oneshot";
    #     RemainAfterExit = true;
    #     ExecStart = ''${pkgs.docker}/bin/docker compose -f /etc/docker/compose/ollama/docker-compose.yml up -d'';
    #     ExecStop = ''${pkgs.docker}/bin/docker compose -f /etc/docker/compose/ollama/docker-compose.yml down'';
    #   };
    # };
  };
}
