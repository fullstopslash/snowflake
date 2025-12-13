# Development tools
#
# General development utilities: CLI tools, debugging, documentation.
#
# Usage:
#   myModules.apps.development.tools.enable = true;
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.apps.development.tools;
in
{
  options.myModules.apps.development.tools = {
    enable = lib.mkEnableOption "Development tools";
  };

  config = lib.mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true; # Caches devShells, dramatically speeds up directory entry
    };

    environment.systemPackages = with pkgs; [
      # GitHub/GitLab workflow tools
      act # GitHub Actions local runner
      gh # GitHub CLI

      # Nix development
      nixpkgs-review

      # Debugging
      screen # serial console, terminal multiplexer
      nmap # network scanning/debugging

      # Documentation
      man-pages
      man-pages-posix
    ];
  };
}
