{ lib, ... }:
{
  imports = map lib.custom.relativeToRoot ([
    "home/common/core"
    "home/common/core/nixos.nix"
  ]);
}
