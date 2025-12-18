# CLI tools rollup role (temporary consolidation)
{ pkgs, ... }:
{
  description = "Core CLI tools";
  config = {
    environment.systemPackages = with pkgs; [
      # Core utilities
      coreutils
      findutils
      curl
      wget
      tree

      # File management
      ripgrep

      # Compression
      zip
      unzip

      # System tools
      pv
      lsof
      jq

      # Version control (required for auto-upgrade)
      gitFull
      jujutsu

      # System monitoring
      btop
    ];
  };
}
