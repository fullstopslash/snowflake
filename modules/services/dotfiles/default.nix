{ lib, ... }:
{
  imports = [
    ./chezmoi-sync.nix  # Uses old format due to custom options
  ];
}
