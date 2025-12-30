# Comma - run programs without installing them
#
# Wraps nix-index-database's comma feature.
# Usage: , <program> - runs program from nixpkgs without installing
{ pkgs, ... }:
{
  # Comma - run programs without installing
  config = {
    programs.nix-index-database.comma.enable = true;
  };
}
