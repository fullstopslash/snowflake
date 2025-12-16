# CLI tools rollup role (temporary consolidation)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.apps.cli.toolsCore;
in
{
  options.myModules.apps.cli.toolsCore = {
    enable = lib.mkEnableOption "Core CLI tools";
  };

  config = lib.mkIf cfg.enable {
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
