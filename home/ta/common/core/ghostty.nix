{ pkgs, lib, ... }:
{
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty.overrideAttrs (_: {
      # https://github.com/NixOS/nixpkgs/issues/421442
      preBuild = lib.optionalString (lib.versionOlder pkgs.unstable.linux.version "6.15.5") ''
        shopt -s globstar
        sed -i 's/^const xev = @import("xev");$/const xev = @import("xev").Epoll;/' **/*.zig
        shopt -u globstar
      '';
    });
    settings = {
      scrollback-limit = 10000;
    };
  };
}
